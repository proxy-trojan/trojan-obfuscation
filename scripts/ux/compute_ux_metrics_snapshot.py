#!/usr/bin/env python3
"""Compute a lightweight UX metrics snapshot for v1.5.0 funnel optimization."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def _safe_div(numerator: int, denominator: int) -> float:
    if denominator <= 0:
        return 0.0
    return numerator / denominator


def compute_snapshot(events: list[dict[str, Any]]) -> dict[str, Any]:
    started_users = {
        str(event.get("userId"))
        for event in events
        if event.get("name") == "first_session_started" and event.get("userId")
    }
    runtime_true_success_users = {
        str(event.get("userId"))
        for event in events
        if event.get("name") == "runtime_session_ready_runtime_true"
        and event.get("userId") in started_users
    }

    action_completed = [
        event for event in events if event.get("name") == "action_completed"
    ]
    action_rework = [
        event for event in events if event.get("name") == "action_rework_detected"
    ]

    recovery_suggested = [
        event for event in events if event.get("name") == "recovery_suggested"
    ]
    recovery_succeeded = [
        event for event in events if event.get("name") == "recovery_succeeded"
    ]

    diagnostics_started = [
        event for event in events if event.get("name") == "diagnostics_export_started"
    ]
    diagnostics_completed = [
        event for event in events if event.get("name") == "diagnostics_export_completed"
    ]

    fcsr_numerator = len(runtime_true_success_users)
    fcsr_denominator = len(started_users)

    # Lightweight HFE placeholders: keep deterministic structure for effect-based closure.
    hfe_t_action = 0.0
    hfe_n_steps = 0.0
    hfe_r_rework = _safe_div(len(action_rework), len(action_completed))
    hfe_index = 0.0

    return {
        "fcsr": {
            "numerator": fcsr_numerator,
            "denominator": fcsr_denominator,
            "value": _safe_div(fcsr_numerator, fcsr_denominator),
        },
        "hfe": {
            "t_action": hfe_t_action,
            "n_steps": hfe_n_steps,
            "r_rework": hfe_r_rework,
            "index": hfe_index,
        },
        "guardrails": {
            "ssr": _safe_div(len(recovery_succeeded), len(recovery_suggested)),
            "ste": _safe_div(len(diagnostics_completed), len(diagnostics_started)),
        },
    }


def _load_events(path: Path) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]
    if isinstance(payload, dict) and isinstance(payload.get("events"), list):
        return [item for item in payload["events"] if isinstance(item, dict)]
    raise ValueError("Input JSON must be an array of events or {'events': [...]}.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--events",
        type=Path,
        required=True,
        help="Path to JSON events file (array or {'events': [...]}).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Optional output path; defaults to stdout when omitted.",
    )
    args = parser.parse_args()

    snapshot = compute_snapshot(events=_load_events(args.events))
    output_text = json.dumps(snapshot, indent=2, ensure_ascii=False)

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output_text + "\n", encoding="utf-8")
    else:
        print(output_text)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
