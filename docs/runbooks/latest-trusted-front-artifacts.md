# Runbook: Latest Trusted-Front Artifacts

## Purpose

Provide stable entry points to the most recent local trusted-front dry-run outputs.

This avoids having to manually locate the newest timestamped validation directory.

## Updated automatically by

- `scripts/run-two-host-trusted-front-local-dry-run.sh`

## Files

- `build/validation/latest-two-host-run.txt`
- `build/validation/latest-two-host-summary.json`
- `build/validation/latest-trusted-front-verdict-draft.md`
- `build/validation/latest-trusted-front-claims-pack.md`
- `build/validation/latest-trusted-front-stage-summary.md`

## Usage

Open these when you want the newest candidate posture quickly:

```bash
cat build/validation/latest-two-host-run.txt
cat build/validation/latest-two-host-summary.json
sed -n '1,220p' build/validation/latest-trusted-front-stage-summary.md
```

## Important limit

These pointers reflect the newest **local dry-run** pipeline output.
They do not turn local evidence into staged public-edge proof.
