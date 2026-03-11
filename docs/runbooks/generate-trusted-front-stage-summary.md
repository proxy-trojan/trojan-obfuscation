# Runbook: Generate Trusted-Front Stage Summary

## Purpose

Generate a one-page stage summary for the current trusted-front candidate state.

This is useful after a serious candidate iteration when you want a compact answer to:
- where are we now?
- what has this stage actually achieved?
- what has it still not earned?
- what should happen next?

## Script

```bash
./scripts/generate-trusted-front-stage-summary.py
```

## Required inputs

- verdict draft markdown
- claims pack markdown
- evidence status markdown
- output markdown path

## Command

```bash
./scripts/generate-trusted-front-stage-summary.py \
  --verdict ./build/validation/<verdict>.md \
  --claims-pack ./build/validation/<claims-pack>.md \
  --evidence-status ./docs/trusted-front-edge-separation-evidence-status.md \
  --output ./build/validation/<stage-summary>.md
```

## What it produces

The stage summary includes:
- forced decision snapshot
- rollout posture snapshot
- what this stage has achieved
- what this stage has not earned
- evidence posture summary
- recommended current positioning
- recommended next step

## Important rule

This summary is a compression layer, not new evidence.
If the underlying verdict or claims pack is weak, the summary must stay conservative too.

For the local two-host dry-run pipeline, `scripts/run-two-host-trusted-front-local-dry-run.sh` now generates this summary automatically when verdict + claims inputs are available.
