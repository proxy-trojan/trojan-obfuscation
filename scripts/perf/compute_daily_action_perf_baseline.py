#!/usr/bin/env python3
"""Compute daily-action performance baselines and evaluate regressions.

This script is deliberately split into two modes:

1) collect: best-effort local measurement intended for human-driven runs.
   The controlled run uses a Troj an client preflight loop (start process, wait
   for local SOCKS port to listen), then captures CPU/memory snapshots.

2) evaluate: deterministic regression evaluation used by CI via synthetic
   fixtures. CI should not depend on a real trojan binary or GUI.

The initial scope targets Iter-3 (Truthful Daily Use) perf guardrails.
"""

from __future__ import annotations

import argparse
import json
import os
import signal
import socket
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class PerfSample:
    """A single performance sample for one action."""

    action: str
    connect_ready_ms: int
    cpu_time_ms: int
    rss_kb: int
    captured_at_utc: str


@dataclass(frozen=True)
class PerfBaseline:
    schema_version: str
    profile: str
    samples: list[PerfSample]


@dataclass(frozen=True)
class ThresholdPolicy:
    """Thresholds for regression evaluation.

    We keep this policy intentionally small at first. The main goal is to make
    regressions visible with explicit rationale.
    """

    schema_version: str
    max_ready_ms_regression_ratio: float
    max_cpu_time_regression_ratio: float
    max_rss_regression_ratio: float


@dataclass(frozen=True)
class RegressionFinding:
    metric: str
    baseline: float
    candidate: float
    ratio: float
    status: str  # pass|warn|fail
    detail: str


def _utc_now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _safe_ratio(candidate: float, baseline: float) -> float:
    if baseline <= 0:
        return float("inf") if candidate > 0 else 1.0
    return candidate / baseline


def _median(values: list[float]) -> float:
    if not values:
        return 0.0
    values_sorted = sorted(values)
    mid = len(values_sorted) // 2
    if len(values_sorted) % 2 == 1:
        return float(values_sorted[mid])
    return float(values_sorted[mid - 1] + values_sorted[mid]) / 2.0


def _read_proc_stat(pid: int) -> tuple[int, int]:
    """Return (utime_ticks, stime_ticks) from /proc/<pid>/stat.

    Linux-only; collect mode is best-effort.
    """

    stat_path = Path(f"/proc/{pid}/stat")
    parts = stat_path.read_text(encoding="utf-8").split()
    # Fields: https://man7.org/linux/man-pages/man5/proc.5.html
    utime = int(parts[13])
    stime = int(parts[14])
    return utime, stime


def _read_proc_rss_kb(pid: int) -> int:
    status_path = Path(f"/proc/{pid}/status")
    for line in status_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("VmRSS:"):
            # VmRSS:   12345 kB
            tokens = line.split()
            for token in tokens:
                if token.isdigit():
                    return int(token)
    return 0


def _ticks_to_ms(ticks: int) -> int:
    hz = os.sysconf(os.sysconf_names["SC_CLK_TCK"])
    return int((ticks / hz) * 1000)


def _wait_port_listen(host: str, port: int, timeout_seconds: float) -> bool:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((host, port), timeout=0.3):
                return True
        except OSError:
            time.sleep(0.05)
    return False


def _choose_free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def _terminate_process(proc: subprocess.Popen[bytes]) -> None:
    if proc.poll() is not None:
        return
    try:
        proc.send_signal(signal.SIGTERM)
        proc.wait(timeout=2)
        return
    except Exception:
        pass
    try:
        proc.kill()
        proc.wait(timeout=2)
    except Exception:
        pass


def collect_perf_sample(*, trojan_bin: str, timeout_seconds: float = 6.0) -> PerfSample:
    """Collect one best-effort connect preflight sample.

    We measure time-to-listen on a local SOCKS port as a proxy for "connect
    ready". This is not the full network connect path (which would require a
    live endpoint), but it is stable enough for a baseline and regression guard.
    """

    port = _choose_free_port()
    tmp_dir = Path("/tmp")
    config_path = tmp_dir / f"trojan-perf-{os.getpid()}-{int(time.time()*1000)}.json"

    config = {
        "run_type": "client",
        "local_addr": "127.0.0.1",
        "local_port": port,
        "remote_addr": "example.com",
        "remote_port": 443,
        "password": ["demo-pass"],
        "log_level": 1,
        "ssl": {
            "verify": True,
            "verify_hostname": True,
            "cert": "",
            "sni": "example.com",
            "alpn": ["h2", "http/1.1"],
            "reuse_session": True,
            "session_ticket": False,
            "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256",
            "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256",
            "curves": "",
        },
        "tcp": {
            "no_delay": True,
            "keep_alive": True,
            "reuse_port": False,
            "fast_open": False,
            "fast_open_qlen": 20,
        },
    }
    config_path.write_text(json.dumps(config), encoding="utf-8")

    started = time.monotonic()
    proc = subprocess.Popen(
        [trojan_bin, "-c", str(config_path)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        pid = proc.pid
        ok = _wait_port_listen("127.0.0.1", port, timeout_seconds=timeout_seconds)
        ready_ms = int((time.monotonic() - started) * 1000)

        # Best-effort snapshots.
        cpu_ms = 0
        rss_kb = 0
        try:
            utime, stime = _read_proc_stat(pid)
            cpu_ms = _ticks_to_ms(utime + stime)
            rss_kb = _read_proc_rss_kb(pid)
        except Exception:
            cpu_ms = 0
            rss_kb = 0

        if not ok:
            # Still return a sample; caller can decide whether to keep it.
            # We keep the schema stable for downstream evaluation.
            pass

        return PerfSample(
            action="connect_preflight",
            connect_ready_ms=ready_ms,
            cpu_time_ms=cpu_ms,
            rss_kb=rss_kb,
            captured_at_utc=_utc_now_iso(),
        )
    finally:
        _terminate_process(proc)
        try:
            config_path.unlink(missing_ok=True)
        except Exception:
            pass


def _baseline_medians(baseline: PerfBaseline) -> dict[str, float]:
    ready = _median([float(s.connect_ready_ms) for s in baseline.samples])
    cpu = _median([float(s.cpu_time_ms) for s in baseline.samples])
    rss = _median([float(s.rss_kb) for s in baseline.samples])
    return {
        "connect_ready_ms": ready,
        "cpu_time_ms": cpu,
        "rss_kb": rss,
    }


def evaluate_regression(
    *,
    baseline: PerfBaseline,
    candidate: PerfBaseline,
    policy: ThresholdPolicy,
) -> list[RegressionFinding]:
    base = _baseline_medians(baseline)
    cand = _baseline_medians(candidate)

    findings: list[RegressionFinding] = []

    def check(metric: str, max_ratio: float) -> None:
        ratio = _safe_ratio(cand[metric], base[metric])
        status = "pass"
        if ratio > max_ratio:
            status = "fail"
        findings.append(
            RegressionFinding(
                metric=metric,
                baseline=base[metric],
                candidate=cand[metric],
                ratio=ratio,
                status=status,
                detail=f"candidate/baseline={ratio:.3f} (max {max_ratio:.3f})",
            )
        )

    check("connect_ready_ms", policy.max_ready_ms_regression_ratio)
    check("cpu_time_ms", policy.max_cpu_time_regression_ratio)
    check("rss_kb", policy.max_rss_regression_ratio)

    return findings


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _load_baseline(path: Path) -> PerfBaseline:
    payload = _load_json(path)
    samples = [PerfSample(**sample) for sample in payload.get("samples", [])]
    return PerfBaseline(
        schema_version=str(payload.get("schema_version", "1")),
        profile=str(payload.get("profile", "unknown")),
        samples=samples,
    )


def _load_policy(path: Path) -> ThresholdPolicy:
    payload = _load_json(path)
    return ThresholdPolicy(
        schema_version=str(payload.get("schema_version", "1")),
        max_ready_ms_regression_ratio=float(
            payload.get("max_ready_ms_regression_ratio", 1.3)
        ),
        max_cpu_time_regression_ratio=float(
            payload.get("max_cpu_time_regression_ratio", 1.5)
        ),
        max_rss_regression_ratio=float(payload.get("max_rss_regression_ratio", 1.5)),
    )


def _write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def cmd_collect(args: argparse.Namespace) -> int:
    samples: list[PerfSample] = []
    for _ in range(int(args.runs)):
        samples.append(
            collect_perf_sample(
                trojan_bin=args.trojan_bin,
                timeout_seconds=float(args.timeout_seconds),
            )
        )

    baseline = PerfBaseline(schema_version="1", profile=str(args.profile), samples=samples)
    _write_json(Path(args.output), asdict(baseline))

    summary = {
        "schema_version": baseline.schema_version,
        "profile": baseline.profile,
        "runs": len(samples),
        "medians": _baseline_medians(baseline),
    }
    if args.summary:
        _write_json(Path(args.summary), summary)

    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


def cmd_evaluate(args: argparse.Namespace) -> int:
    baseline = _load_baseline(Path(args.baseline))
    candidate = _load_baseline(Path(args.candidate))
    policy = _load_policy(Path(args.policy))

    findings = evaluate_regression(baseline=baseline, candidate=candidate, policy=policy)
    out = {
        "baseline": {
            "profile": baseline.profile,
            "medians": _baseline_medians(baseline),
        },
        "candidate": {
            "profile": candidate.profile,
            "medians": _baseline_medians(candidate),
        },
        "policy": asdict(policy),
        "findings": [asdict(f) for f in findings],
        "passed": all(f.status == "pass" for f in findings),
    }

    if args.output:
        _write_json(Path(args.output), out)

    print(json.dumps(out, indent=2, ensure_ascii=False))
    return 0 if out["passed"] else 2


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    collect = sub.add_parser("collect", help="collect a local perf baseline")
    collect.add_argument("--trojan-bin", required=True, help="path to trojan binary")
    collect.add_argument("--profile", default="local", help="profile label")
    collect.add_argument("--runs", type=int, default=5, help="number of samples")
    collect.add_argument("--timeout-seconds", type=float, default=6.0)
    collect.add_argument("--output", required=True, help="baseline json output path")
    collect.add_argument("--summary", help="optional summary json output path")
    collect.set_defaults(func=cmd_collect)

    evaluate = sub.add_parser("evaluate", help="evaluate regression baseline vs candidate")
    evaluate.add_argument("--baseline", required=True, help="baseline json path")
    evaluate.add_argument("--candidate", required=True, help="candidate json path")
    evaluate.add_argument("--policy", required=True, help="threshold policy json path")
    evaluate.add_argument("--output", help="optional evaluation output json path")
    evaluate.set_defaults(func=cmd_evaluate)

    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
