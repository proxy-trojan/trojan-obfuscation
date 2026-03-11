# Trusted-Front / Edge Separation Evidence Status

## Status

Current-state evidence summary

## Date

2026-03-11

## Purpose

State clearly what the project has **actually proven so far** about trusted-front / edge separation, using current in-tree artifacts only.

This report is intentionally strict.
It exists to separate:

- architectural readiness
- execution readiness
- evidence of real public-edge improvement

Those are not the same thing.

---

# 1. Short Answer

## What is already proven
The project has now proven a **real candidate path and a real execution support loop** for trusted-front work.

Specifically, current evidence supports these claims:
- a trusted-front candidate runtime path exists
- an mTLS-capable internal listener shape exists
- baseline and candidate evidence can be captured in a comparable structure
- baseline vs candidate profile split is now explicit and machine-checkable
- a local dry run of the two-host execution loop can close successfully

## What is not yet proven
The project has **not yet proven**:
- a real two-host trust boundary result
- a stronger public-facing posture than baseline
- improved passive public observation characteristics
- improved anti-probing performance in a realistic staged deployment
- first-tier public-edge camouflage status

## One-line verdict

> Trusted-front / edge separation is now **evidence-backed as a serious candidate direction**, but **not yet evidence-backed as a detectability upgrade over the current baseline**.

---

# 2. Evidence Inventory

## A. Baseline evidence bundle
Evidence:
- `build/validation/baseline-commit-ready/summary.json`
- `build/validation/baseline-commit-ready/profile-mode.json`
- `build/validation/baseline-commit-ready/config.snapshot.json`

What it proves:
- baseline bundle shape exists
- baseline profile mode is explicitly recorded as `baseline`
- baseline evidence is structured for later comparison

## B. Candidate evidence bundle
Evidence:
- `build/validation/candidate-commit-ready/summary.json`
- `build/validation/candidate-commit-ready/profile-mode.json`
- `build/validation/candidate-commit-ready/config.snapshot.json`

What it proves:
- candidate bundle shape exists
- candidate profile mode is explicitly recorded as `candidate`
- trusted-front listener path can be exercised locally
- candidate evidence is structured for later comparison

## C. Summary-level comparison evidence
Evidence:
- `build/validation/commit-ready-comparison.md`

What it proves:
- baseline/candidate mode split is no longer ambiguous
- the two evidence bundles are comparable at a structural level

What it does not prove:
- public-edge improvement
- candidate superiority
- first-tier status

## D. Two-host execution support dry run
Evidence:
- `docs/two-host-trusted-front-dry-run-report.md`
- `build/validation/latest-two-host-summary.json`
- `build/validation/latest-two-host-run.txt`
- `build/validation/two-host-dry-run-20260311-134929`

What it proves:
- bundle preparation works
- backend candidate start/stop support works
- front-side sender integration works well enough for dry-run closure
- artifacts can be collected in one loop

What it does not prove:
- real front/backend network separation
- real two-host trust boundary
- real public-edge improvement

---

# 3. Claim-by-Claim Status

## Claim 1 — "Trusted-front candidate path exists"
### Status
**Proven**

### Why
The local candidate evidence run and the current candidate bundle confirm that the trusted-front candidate path can start and be exercised locally.

Supporting evidence:
- `docs/trusted-front-candidate-validation-report.md`
- `build/validation/candidate-commit-ready/summary.json`

---

## Claim 2 — "mTLS-capable internal trust boundary exists"
### Status
**Proven locally**

### Why
The candidate evidence bundle records an mTLS-capable trusted-front listener shape and a client-side transport attempt against it.

Supporting evidence:
- `docs/trusted-front-candidate-validation-report.md`
- `build/validation/candidate-commit-ready/summary.json`

### Important limit
This proves a **local executable trust-boundary shape**, not a real staged network trust boundary across separate hosts.

---

## Claim 3 — "Trusted-front execution flow is operationally real"
### Status
**Proven for local dry-run support**

### Why
The two-host dry-run report confirms the execution loop now closes:

```text
prepare bundle
-> start backend candidate
-> run front-side sender
-> collect artifacts
-> stop backend candidate
```

Supporting evidence:
- `docs/two-host-trusted-front-dry-run-report.md`
- `build/validation/latest-two-host-summary.json`

### Important limit
This is an execution-support proof, not a detectability proof.

---

## Claim 4 — "Baseline vs candidate comparison is evidence-backed"
### Status
**Partially proven**

### Why
The project now has:
- explicit profile separation
- structured evidence bundles
- summary-level comparison tooling
- scorecard and runbooks to force judgment

Supporting evidence:
- `build/validation/commit-ready-comparison.md`
- `docs/first-tier-promotion-scorecard.md`
- `docs/runbooks/compare-validation-summaries.md`

### Important limit
This proves **comparison readiness**, not yet **comparison victory**.

---

## Claim 5 — "Trusted-front / edge separation already improves detectability"
### Status
**Not proven**

### Why not
Current evidence is still limited to:
- local candidate execution
- local dry-run execution support
- structural comparison readiness

The project still lacks:
- real two-host staging evidence
- before/after public-edge observation evidence
- staged active-probing comparison
- public-surface realism evidence from a true separated edge

Supporting restraint:
- `docs/baseline-vs-trusted-front-candidate-comparison-report.md`
- `docs/trusted-front-candidate-validation-report.md`

---

## Claim 6 — "The project has entered the first tier"
### Status
**Not proven**

### Why not
The current project has moved from:
- trusted-front preparation

to:
- trusted-front candidate runtime reality
- structured evidence collection
- operationally real dry-run execution support

But first-tier claims require proof of:
- materially improved public-edge posture
- materially stronger passive-public behavior
- materially stronger staged anti-probing behavior

Current evidence does not establish those.

---

# 4. Practical Interpretation

## What has changed materially
The project is no longer blocked on:
- candidate-path existence
- evidence-bundle structure
- baseline/candidate profile ambiguity
- local staged-run orchestration support

That is real progress.

## What has not changed materially
The project has not yet crossed the boundary from:
- "prepared to prove stronger public-edge posture"

to:
- "has already proven stronger public-edge posture"

That boundary still requires stronger staged evidence.

---

# 5. Final Verdict

## Honest current position
The project now has:
- a **strong second-tier practical baseline**
- a **materially real trusted-front candidate runtime path**
- a **usable local staged-run support loop**
- a **more serious evidence and rollback discipline than before**

## Honest detectability conclusion
Trusted-front / edge separation is currently best described as:

> **evidence-backed as the project’s most credible route toward first-tier posture**

but **not yet evidence-backed as a delivered first-tier upgrade**.

## Final short version

- **Candidate path existence:** proven
- **Local trust-boundary shape:** proven
- **Dry-run execution support:** proven
- **Real two-host staged detectability improvement:** not proven
- **First-tier claim:** not proven
