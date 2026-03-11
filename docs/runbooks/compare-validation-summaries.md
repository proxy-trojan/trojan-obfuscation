# Runbook: Compare Validation Summaries

## Purpose

Generate a small, repeatable summary-level comparison between:

- one baseline validation bundle
- one trusted-front candidate validation bundle

This runbook is intentionally narrow.
It validates that the comparison inputs are structurally aligned before a human writes the fuller verdict.

## Script

```bash
./scripts/compare-validation-summaries.py
```

## Required inputs

- baseline `summary.json`
- candidate `summary.json`
- output markdown path

## Command

```bash
./scripts/compare-validation-summaries.py \
  --baseline ./build/validation/<baseline-dir>/summary.json \
  --candidate ./build/validation/<candidate-dir>/summary.json \
  --output ./build/validation/<comparison-name>.md
```

## What it checks

The script compares:
- profile mode labels
- public / fallback / trusted-front port snapshots
- config snapshot paths
- profile-mode artifact paths

## What it does NOT prove

This script does **not** prove:
- public-edge improvement
- first-tier status
- candidate superiority

It only helps answer a lower-level question first:

> Are baseline and candidate bundles structured cleanly enough to support a meaningful comparison?

## Recommended next step

After generating the comparison markdown, finish the judgment with:
- `docs/first-tier-promotion-scorecard.md`
- the relevant validation report
- operator notes from the run
