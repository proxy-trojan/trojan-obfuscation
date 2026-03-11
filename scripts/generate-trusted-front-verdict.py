#!/usr/bin/env python3
import argparse
import json
import pathlib


def load_json(path: str):
    return json.loads(pathlib.Path(path).read_text())


def classify_input_completeness(baseline, candidate):
    baseline_ok = baseline.get("profile_label") == "baseline" and baseline.get("profile_mode", {}).get("mode") == "baseline"
    candidate_ok = candidate.get("profile_label") == "candidate" and candidate.get("profile_mode", {}).get("mode") == "candidate"
    return baseline_ok and candidate_ok, baseline_ok, candidate_ok


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a baseline-vs-trusted-front verdict draft")
    parser.add_argument("--baseline", required=True, help="path to baseline summary.json")
    parser.add_argument("--candidate", required=True, help="path to candidate summary.json")
    parser.add_argument("--comparison", required=True, help="path to comparison markdown")
    parser.add_argument("--output", required=True, help="path to output markdown")
    parser.add_argument("--scope", default="local validation comparison", help="scope description")
    parser.add_argument("--candidate-shape", default="trusted-front candidate", help="candidate shape description")
    parser.add_argument("--two-host-summary", help="optional path to two-host dry-run or staging summary.json")
    args = parser.parse_args()

    baseline = load_json(args.baseline)
    candidate = load_json(args.candidate)
    two_host = load_json(args.two_host_summary) if args.two_host_summary else None
    output_path = pathlib.Path(args.output)

    inputs_ok, baseline_ok, candidate_ok = classify_input_completeness(baseline, candidate)

    final_decision = "Improved but not enough" if inputs_ok else "Not ready"
    blunt_verdict = (
        "The candidate is more operationally real than before, but this evidence still does not prove a public-edge win over baseline."
        if inputs_ok else
        "The comparison inputs are incomplete or ambiguous, so no credible candidate verdict can be made yet."
    )

    lines = []
    lines.append("# Baseline vs Trusted-Front Verdict Draft")
    lines.append("")
    lines.append("## Run Identity")
    lines.append(f"- **Scope:** {args.scope}")
    lines.append(f"- **Candidate shape:** {args.candidate_shape}")
    lines.append(f"- **Baseline evidence path:** `{args.baseline}`")
    lines.append(f"- **Candidate evidence path:** `{args.candidate}`")
    lines.append(f"- **Comparison artifact path:** `{args.comparison}`")
    lines.append("")
    lines.append("## Input Completeness Check")
    lines.append(f"- Baseline mode valid: **{'yes' if baseline_ok else 'no'}**")
    lines.append(f"- Candidate mode valid: **{'yes' if candidate_ok else 'no'}**")
    lines.append(f"- Baseline profile label: `{baseline.get('profile_label', 'unknown')}`")
    lines.append(f"- Candidate profile label: `{candidate.get('profile_label', 'unknown')}`")
    lines.append("")
    lines.append("## Machine-Readable Snapshot")
    lines.append(f"- Baseline public port: `{baseline.get('ports', {}).get('public', 'n/a')}`")
    lines.append(f"- Candidate public port: `{candidate.get('ports', {}).get('public', 'n/a')}`")
    lines.append(f"- Candidate trusted-front port: `{candidate.get('ports', {}).get('trusted_front', 'n/a')}`")
    lines.append(f"- Baseline config snapshot: `{baseline.get('artifact_paths', {}).get('config_snapshot', 'n/a')}`")
    lines.append(f"- Candidate config snapshot: `{candidate.get('artifact_paths', {}).get('config_snapshot', 'n/a')}`")
    if two_host is not None:
        lines.append(f"- Two-host summary: `{args.two_host_summary}`")
        lines.append(f"- Two-host front response present: `{two_host.get('front_response_present', 'n/a')}`")
        lines.append(f"- Two-host local-check response seen: `{two_host.get('front_response_contains_local_check', 'n/a')}`")
        lines.append(f"- Two-host handoff applied signal seen: `{two_host.get('handoff_applied', 'n/a')}`")
        lines.append(f"- Two-host fallback path seen: `{two_host.get('fallback_path_seen', 'n/a')}`")
        lines.append(f"- Two-host tunnel established: `{two_host.get('tunnel_established', 'n/a')}`")
        lines.append(f"- Two-host trusted-front rejected: `{two_host.get('trusted_front_rejected', 'n/a')}`")
    lines.append("")
    lines.append("## Forced Draft Judgment")
    lines.append("### Passive public observation")
    lines.append("- Draft verdict: **Same**")
    lines.append("- Draft why: current inputs are local/structural and do not prove stronger public-edge posture.")
    lines.append("")
    lines.append("### Active probing behavior")
    lines.append("- Draft verdict: **Same**")
    if two_host is not None:
        lines.append("- Draft why: two-host execution support evidence improves operational confidence, but it still does not prove stronger external anti-probing behavior.")
    else:
        lines.append("- Draft why: candidate path is more real operationally, but current evidence does not prove stronger external anti-probing behavior.")
    lines.append("")
    lines.append("### Public-surface realism")
    lines.append("- Draft verdict: **Same**")
    lines.append("- Draft why: baseline still has stronger directly observed public-surface evidence than the current local candidate snapshot.")
    lines.append("")
    lines.append("### Operator clarity")
    lines.append("- Draft verdict: **Better**")
    lines.append("- Draft why: profile split, evidence bundles, scorecard, and runbooks now make candidate-path reasoning clearer and less ambiguous.")
    lines.append("")
    lines.append("### Rollback confidence")
    lines.append("- Draft verdict: **Same**")
    lines.append("- Draft why: candidate rollback discipline improved, but baseline remains the safer and more proven mainline posture.")
    lines.append("")
    lines.append("### Net value vs added complexity")
    lines.append("- Draft verdict: **Unclear**")
    if two_host is not None:
        lines.append("- Draft why: two-host execution support now looks more operationally real, but detectability value over baseline is still not demonstrated.")
    else:
        lines.append("- Draft why: candidate readiness improved meaningfully, but detectability value over baseline is still not demonstrated.")
    lines.append("")
    lines.append("## Scorecard Mapping")
    lines.append("- Baseline Stability Preserved: **Pass**")
    lines.append("- Evidence Quality: **Pass**" if inputs_ok else "- Evidence Quality: **Fail**")
    lines.append("- Operator Clarity: **Pass**")
    lines.append("- Rollback Confidence: **Mixed**")
    lines.append("- Public-Edge Separation Readiness: **Mixed**")
    lines.append("- Net Value vs Added Complexity: **Mixed**")
    lines.append("")
    lines.append("## Forced Final Decision")
    lines.append(f"- **Decision:** {final_decision}")
    lines.append("")
    lines.append("## Blunt One-Sentence Verdict")
    lines.append("")
    lines.append(f"> {blunt_verdict}")
    lines.append("")
    lines.append("## Allowed Claims After This Run")
    lines.append("### Justified")
    lines.append("- trusted-front candidate path exists")
    lines.append("- local trusted-front boundary shape exists")
    lines.append("- candidate evidence is now structurally comparable to baseline")
    if two_host is not None:
        lines.append("- two-host execution support loop is operationally real enough for dry-run evidence")
    lines.append("")
    lines.append("### Not yet justified")
    lines.append("- trusted-front already improves detectability over baseline")
    lines.append("- trusted-front is ready for production promotion")
    lines.append("- the project has entered the first tier")
    if two_host is not None:
        lines.append("- two-host dry-run success equals public-edge victory")
    lines.append("")
    lines.append("## Next Action")
    lines.append("- **Recommended:** run another narrow staging iteration with stronger public-edge evidence rather than extending backend-native transport scope.")

    output_path.write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
