#!/usr/bin/env python3
import argparse
import json
import pathlib


def load_json(path: str):
    return json.loads(pathlib.Path(path).read_text())


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare baseline and candidate validation summaries")
    parser.add_argument("--baseline", required=True, help="path to baseline summary.json")
    parser.add_argument("--candidate", required=True, help="path to candidate summary.json")
    parser.add_argument("--output", required=True, help="markdown output path")
    args = parser.parse_args()

    baseline = load_json(args.baseline)
    candidate = load_json(args.candidate)

    baseline_mode = baseline.get("profile_mode", {}).get("mode", "unknown")
    candidate_mode = candidate.get("profile_mode", {}).get("mode", "unknown")

    lines = []
    lines.append("# Validation Summary Comparison")
    lines.append("")
    lines.append("## Inputs")
    lines.append(f"- Baseline summary: `{args.baseline}`")
    lines.append(f"- Candidate summary: `{args.candidate}`")
    lines.append("")
    lines.append("## Profile Check")
    lines.append(f"- Baseline mode: **{baseline_mode}**")
    lines.append(f"- Candidate mode: **{candidate_mode}**")
    lines.append("")
    lines.append("## Port Snapshot")
    lines.append(f"- Baseline public port: `{baseline.get('ports', {}).get('public', 'n/a')}`")
    lines.append(f"- Baseline fallback port: `{baseline.get('ports', {}).get('fallback', 'n/a')}`")
    lines.append(f"- Candidate public port: `{candidate.get('ports', {}).get('public', 'n/a')}`")
    lines.append(f"- Candidate trusted-front port: `{candidate.get('ports', {}).get('trusted_front', 'n/a')}`")
    lines.append(f"- Candidate fallback port: `{candidate.get('ports', {}).get('fallback', 'n/a')}`")
    lines.append("")
    lines.append("## Artifact Snapshot")
    lines.append(f"- Baseline config snapshot: `{baseline.get('artifact_paths', {}).get('config_snapshot', 'n/a')}`")
    lines.append(f"- Candidate config snapshot: `{candidate.get('artifact_paths', {}).get('config_snapshot', 'n/a')}`")
    lines.append(f"- Baseline profile mode file: `{baseline.get('artifact_paths', {}).get('profile_mode', 'n/a')}`")
    lines.append(f"- Candidate profile mode file: `{candidate.get('artifact_paths', {}).get('profile_mode', 'n/a')}`")
    lines.append("")
    lines.append("## Forced Judgment Hints")
    if baseline_mode == "baseline" and candidate_mode == "candidate":
        lines.append("- Mode split looks correct: baseline and candidate are no longer ambiguous.")
    else:
        lines.append("- Mode split is suspicious: fix profile selection before trusting comparison claims.")
    lines.append("- This comparison is summary-level only; it does not prove a public-edge tier upgrade by itself.")
    lines.append("- Use this output together with `docs/first-tier-promotion-scorecard.md` for the final verdict.")
    lines.append("")
    lines.append("## Recommended Next Step")
    lines.append("- If the mode split is correct, continue with richer evidence comparison rather than new transport expansion.")

    output_path = pathlib.Path(args.output)
    output_path.write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
