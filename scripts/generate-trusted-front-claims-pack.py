#!/usr/bin/env python3
import argparse
import pathlib
import re


def read_text(path: str) -> str:
    return pathlib.Path(path).read_text()


def extract_decision(verdict_text: str) -> str:
    m = re.search(r"- \*\*Decision:\*\* (.+)", verdict_text)
    return m.group(1).strip() if m else "Unknown"


def extract_section_lines(text: str, heading: str):
    pattern = re.compile(rf"^### {re.escape(heading)}\n(.*?)(?=^### |\Z)", re.M | re.S)
    m = pattern.search(text)
    if not m:
        return []
    block = m.group(1)
    return [line.strip()[2:] for line in block.splitlines() if line.strip().startswith("- ")]


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a trusted-front claims pack from verdict/evidence docs")
    parser.add_argument("--verdict", required=True, help="path to verdict draft markdown")
    parser.add_argument("--evidence-status", required=True, help="path to evidence status markdown")
    parser.add_argument("--rollout-checklist", required=True, help="path to rollout checklist markdown")
    parser.add_argument("--output", required=True, help="path to output markdown")
    args = parser.parse_args()

    verdict_text = read_text(args.verdict)
    evidence_text = read_text(args.evidence_status)
    rollout_text = read_text(args.rollout_checklist)

    decision = extract_decision(verdict_text)
    justified = extract_section_lines(verdict_text, "Justified")
    not_justified = extract_section_lines(verdict_text, "Not yet justified")

    rollout_posture = "Not approved — fix gaps first"
    if "Approved for narrow canary" in rollout_text and decision == "Ready for narrow promotion":
        rollout_posture = "Approved for narrow canary"
    elif "Approved for staging" in rollout_text and decision in {"Improved but not enough", "Ready for narrow promotion"}:
        rollout_posture = "Prepared for staging only"

    lines = []
    lines.append("# Trusted-Front Claims Pack")
    lines.append("")
    lines.append("## Forced Decision Snapshot")
    lines.append(f"- **Verdict decision:** {decision}")
    lines.append(f"- **Rollout posture:** {rollout_posture}")
    lines.append("")
    lines.append("## Allowed Claims")
    if justified:
        for item in justified:
            lines.append(f"- {item}")
    else:
        lines.append("- none extracted")
    lines.append("")
    lines.append("## Not Yet Justified Claims")
    if not_justified:
        for item in not_justified:
            lines.append(f"- {item}")
    else:
        lines.append("- none extracted")
    lines.append("")
    lines.append("## Evidence Posture Summary")
    lines.append("- trusted-front / edge separation is evidence-backed as a serious candidate direction")
    lines.append("- detectability upgrade over baseline is not yet proven")
    lines.append("- first-tier claim is not yet proven")
    lines.append("")
    lines.append("## Safe External Summary")
    if decision == "Improved but not enough":
        lines.append("> Trusted-front candidate is more operationally real than before, but current evidence still does not prove a public-edge win over baseline.")
    elif decision == "Ready for narrow promotion":
        lines.append("> Trusted-front candidate has earned a narrow promotion claim, but only within the validated staging scope.")
    else:
        lines.append("> Trusted-front candidate is not yet in a state that supports a stronger external claim.")
    lines.append("")
    lines.append("## Operator Reminder")
    lines.append("- do not turn dry-run success into a public-edge victory claim")
    lines.append("- do not turn candidate existence into production-readiness claims")
    lines.append("- keep baseline as mainline until staged public-edge evidence says otherwise")

    pathlib.Path(args.output).write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
