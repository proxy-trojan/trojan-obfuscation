# Runbook: Fill Baseline vs Trusted-Front Verdict

## Purpose

Turn a finished baseline-vs-candidate validation run into a forced decision rather than an impressionistic summary.

## Template

Use:
- `docs/baseline-vs-trusted-front-verdict-template.md`

## Required inputs

- baseline evidence bundle
- candidate evidence bundle
- comparison markdown / notes
- rollout or rollback notes when relevant
- scorecard reference: `docs/first-tier-promotion-scorecard.md`

## Steps

1. confirm both baseline and candidate inputs are complete
2. verify profile labels are correct (`baseline` vs `candidate`)
3. compare passive public observation notes
4. compare active probing notes
5. compare public-surface realism notes
6. compare operator clarity and rollback confidence
7. map the result into the first-tier scorecard
8. force one final decision
9. explicitly list which claims are justified and which are not

## Important rule

Do **not** skip from:
- candidate path ran

to:
- candidate improved detectability

Those are different claims.

## Good final outputs

A good completed verdict should make it easy to answer:
- did the candidate really improve the public edge?
- if yes, was the gain large enough to justify complexity?
- if no, is the right next step iteration, rollback, or pause?

## Bad final outputs

Avoid verdicts like:
- "promising"
- "looks better"
- "probably stronger"
- "feels close to first-tier"

unless they are backed by the forced decision fields in the template.
