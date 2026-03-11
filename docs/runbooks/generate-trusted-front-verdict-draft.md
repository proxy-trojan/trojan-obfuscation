# Runbook: Generate Trusted-Front Verdict Draft

## Purpose

Generate a first-pass verdict draft from baseline and candidate validation summaries.

This runbook does **not** replace human review.
It exists to force a consistent starting structure so verdicts do not drift into vague prose.

## Script

```bash
./scripts/generate-trusted-front-verdict.py
```

## Required inputs

- baseline `summary.json`
- candidate `summary.json`
- comparison markdown
- output markdown path

## Optional input

- two-host dry-run or staging `summary.json`

## Command

```bash
./scripts/generate-trusted-front-verdict.py \
  --baseline ./build/validation/<baseline-dir>/summary.json \
  --candidate ./build/validation/<candidate-dir>/summary.json \
  --comparison ./build/validation/<comparison>.md \
  --output ./build/validation/<verdict>.md \
  [--two-host-summary ./build/validation/<two-host-run>/summary.json]
```

## What it produces

The draft includes:
- input completeness check
- machine-readable snapshot of key ports and config artifacts
- optional two-host execution-support snapshot
- draft per-dimension verdicts
- scorecard mapping draft
- forced final decision draft
- justified vs unjustified claims section

## Important limit

The script can help structure the verdict.
It cannot prove public-edge improvement by itself.
Even with `--two-host-summary`, dry-run execution support is not the same thing as a detectability upgrade.

If the draft says "Improved but not enough", that means:
- the candidate is more real than before
- but the current evidence still does not justify a tier upgrade claim
