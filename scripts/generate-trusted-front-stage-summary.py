#!/usr/bin/env python3
import argparse
import pathlib
import re


def read_text(path: str) -> str:
    return pathlib.Path(path).read_text()


def extract_first(pattern: str, text: str, default: str = "Unknown") -> str:
    m = re.search(pattern, text, re.M)
    return m.group(1).strip() if m else default


def extract_list_block(text: str, heading: str):
    pattern = re.compile(rf"^## {re.escape(heading)}\n(.*?)(?=^## |\Z)", re.M | re.S)
    m = pattern.search(text)
    if not m:
        return []
    block = m.group(1)
    return [line.strip()[2:] for line in block.splitlines() if line.strip().startswith("- ")]


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a trusted-front stage summary")
    parser.add_argument("--verdict", required=True, help="path to verdict draft markdown")
    parser.add_argument("--claims-pack", required=True, help="path to claims pack markdown")
    parser.add_argument("--evidence-status", required=True, help="path to evidence status markdown")
    parser.add_argument("--output", required=True, help="path to output markdown")
    args = parser.parse_args()

    verdict_text = read_text(args.verdict)
    claims_text = read_text(args.claims_pack)
    evidence_text = read_text(args.evidence_status)

    decision = extract_first(r"- \*\*Decision:\*\* (.+)", verdict_text)
    rollout_posture = extract_first(r"- \*\*Rollout posture:\*\* (.+)", claims_text)
    blunt = extract_first(r"^> (.+)", verdict_text)

    allowed = extract_list_block(claims_text, "Allowed Claims")
    not_yet = extract_list_block(claims_text, "Not Yet Justified Claims")

    proven = []
    not_proven = []
    for line in evidence_text.splitlines():
        if line.startswith("- **") and line.endswith(":** proven"):
            proven.append(line.strip()[2:])
        elif line.startswith("- **") and line.endswith(":** not proven"):
            not_proven.append(line.strip()[2:])

    lines = []
    lines.append("# Trusted-Front Candidate Stage Summary")
    lines.append("")
    lines.append("## Current Stage Snapshot")
    lines.append(f"- **Forced decision:** {decision}")
    lines.append(f"- **Rollout posture:** {rollout_posture}")
    lines.append(f"- **Blunt verdict:** {blunt}")
    lines.append("")
    lines.append("## What This Stage Has Achieved")
    if allowed:
        for item in allowed:
            lines.append(f"- {item}")
    else:
        lines.append("- no allowed-claims block found")
    lines.append("")
    lines.append("## What This Stage Has NOT Yet Earned")
    if not_yet:
        for item in not_yet:
            lines.append(f"- {item}")
    else:
        lines.append("- no not-yet-justified block found")
    lines.append("")
    lines.append("## Evidence Posture")
    lines.append("- trusted-front / edge separation is evidence-backed as a serious candidate direction")
    lines.append("- detectability upgrade over baseline is not yet proven")
    lines.append("- first-tier status is not yet proven")
    lines.append("")
    lines.append("## Recommended Current Positioning")
    lines.append("- keep baseline as the production mainline")
    lines.append("- keep trusted-front as a staging/candidate line")
    lines.append("- use this stage only to justify further validation, not promotion")
    lines.append("")
    lines.append("## Recommended Next Step")
    lines.append("- run another narrow staging iteration with stronger public-edge evidence")
    lines.append("- keep verdict + claims generation attached to every serious candidate run")
    lines.append("- do not claim detectability improvement until two-host staged evidence exists")

    pathlib.Path(args.output).write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
