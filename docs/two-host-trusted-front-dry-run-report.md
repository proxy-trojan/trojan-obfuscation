# Two-Host Trusted-Front Dry-Run Report

## Status

Initial local dry-run snapshot

## Date

2026-03-11

## Purpose

Record the first **single-host dry run of the two-host execution flow**.

This report is intentionally conservative.
It does **not** claim a real two-host staging result.
It only answers a narrower question:

> Does the newly added two-host execution support flow close the loop locally?

## Execution Shape

This dry run simulated the two-host workflow using local resources:
- generated two-host staging bundle
- backend candidate start script
- front-side transport sender
- backend candidate stop script
- local fallback stub

## Evidence Location

- `build/validation/two-host-dry-run-20260311-134413`

---

# 1. What This Dry Run Was Intended To Prove

The dry run was only intended to prove:
1. the two-host staging bundle is usable
2. the backend candidate can be started from the generated bundle
3. the front-side sender can exercise the trusted-front candidate path using that bundle
4. evidence artifacts can be collected in one place
5. the backend candidate can be stopped cleanly

It was **not** intended to prove:
- network realism across two actual hosts
- production trusted-front readiness
- improved public-edge posture over the baseline
- first-tier detectability status

---

# 2. Dry-Run Result

## Overall result
**Closed-loop execution support confirmed locally**

## Meaning
The following flow now exists and can be exercised end-to-end in a local dry run:

```text
prepare bundle
-> start backend candidate
-> run front-side trusted-front transport sender
-> collect backend/front artifacts
-> stop backend candidate
```

This is meaningful progress because it moves the project beyond:
- isolated backend candidate code
- isolated front-side sender tooling
- isolated staging-preparation artifacts

The pieces now form a usable execution support loop.

---

# 3. What Was Verified

## A. Bundle usability
The generated two-host staging bundle could be reused directly as the basis for the dry run.

## B. Backend execution support
The backend candidate start flow now has a practical wrapper that can:
- generate a runtime config
- start the candidate process
- write logs and pid files
- expose a concrete trusted-front listener target

## C. Front execution support
The front-side sender now has a usable entry point that can:
- consume trust material from the bundle
- send the trusted-front frame format
- write a captured response artifact

## D. Stop/cleanup support
The backend candidate stop flow now exists as an explicit script rather than an ad hoc process-management step.

---

# 4. What This Dry Run Did NOT Prove

This dry run does **not** change the project’s tier status.

## Not proven
- a real two-host trust boundary
- real network separation between front and backend
- public-edge improvement over baseline
- improved passive public observation characteristics
- stronger anti-probing performance than baseline

## Why this matters
A clean local dry run means the project is more executable.
It does **not** mean the project is more stealthy in the real world.

---

# 5. Current Judgment

## Project state after this dry run
The project now has:
- local baseline evidence
- local trusted-front candidate evidence
- two-host staging preparation
- two-host execution support flow
- local dry-run confirmation that the execution flow can close the loop

## Tier status
The project is still best described as:
- **strong second-tier practical baseline**
- with a **materially real trusted-front candidate runtime path**
- and now a **usable two-host execution support loop**

That is progress, but it is still **not** a first-tier claim.

---

# 6. Next Required Step

The next step that matters is no longer more local plumbing.

It is:
- a **real two-host staging execution**
- using the same execution support flow
- with evidence collected under the Phase 4 workflow
- followed by an updated candidate-vs-baseline comparison

## Final short verdict
This dry run proves:
- **the two-host execution flow is now operationally prepared**

It does not yet prove:
- **the trusted-front candidate wins**
- **the project has entered the first tier**
