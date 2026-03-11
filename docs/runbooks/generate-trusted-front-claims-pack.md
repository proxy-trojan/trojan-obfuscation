# Runbook: Generate Trusted-Front Claims Pack

## Purpose

Generate a short claims pack that answers three practical questions after a candidate run:

- what can we safely claim now?
- what is still not justified?
- what rollout posture is appropriate?

## Script

```bash
./scripts/generate-trusted-front-claims-pack.py
```

## Required inputs

- verdict draft markdown
- evidence status markdown
- rollout checklist markdown
- output markdown path

## Command

```bash
./scripts/generate-trusted-front-claims-pack.py \
  --verdict ./build/validation/<verdict>.md \
  --evidence-status ./docs/trusted-front-edge-separation-evidence-status.md \
  --rollout-checklist ./docs/trusted-front-rollout-checklist.md \
  --output ./build/validation/<claims-pack>.md
```

## What it produces

The claims pack includes:
- verdict decision snapshot
- rollout posture summary
- allowed claims
- not-yet-justified claims
- a short safe external summary
- operator reminders against overselling

## Important rule

Use this only after the verdict draft exists.
The claims pack is a communication aid, not a replacement for evidence review.

For the local two-host dry-run pipeline, `scripts/run-two-host-trusted-front-local-dry-run.sh` now generates this pack automatically when baseline/candidate comparison inputs are present.
