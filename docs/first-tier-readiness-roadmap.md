# First-Tier Readiness Roadmap

## Status

Draft

## Purpose

Turn the project’s current Phase 4 direction into a concrete roadmap for closing the gap between:

- **strong second-tier practical baseline**
- **first-tier engineering readiness**

This roadmap is intentionally strict.
It does **not** treat internal architecture progress alone as a tier upgrade.
It only counts progress that improves one or more of these without regressing baseline quality:

- evidence quality
- operator clarity
- rollback safety
- deployment discipline
- public-edge separation readiness

## Current Honest Position

Today the project already has:

- a real Trojan over TCP/TLS baseline
- fallback-backed deployment posture
- runtime guardrails
- seam-level tests
- external-front preparation and candidate runtime path
- rollout / rollback / validation documentation

Today the project still lacks:

- a proven tier upgrade over the baseline
- a decision-grade evidence loop for candidate-vs-baseline comparison
- a hardened profile split that operators can use without ambiguity
- a repeatable staging harness that proves readiness rather than just path existence

## North Star

> Keep the backend stable, improve the public edge.

Translated into execution terms:

1. do **not** destabilize the current baseline
2. do **not** count parser / seam growth as tier progress by itself
3. do **not** claim tier upgrades without before/after evidence
4. treat first-tier progress as a **deployment-quality + observability + rollback + public-edge readiness** problem

---

# 1. First-Tier Gate Definition

The project should not describe itself as having entered the first tier until all gates below are met.

## Gate A — Baseline must stay dominant

The current baseline must remain:

- deployable
- testable
- rollback-friendly
- operator-comprehensible

### Required signs
- baseline smoke path remains green
- runtime seam tests remain green
- config defaults remain baseline-safe
- release artifacts still work without candidate-only assumptions

## Gate B — Candidate evidence must beat "path existence"

The candidate must prove more than:

- listener starts
- mTLS handoff works
- frame parsing works

### Required signs
- candidate evidence is collected in the same structure as baseline evidence
- evidence can be compared run-to-run
- operator-visible signals are stable enough to support blunt judgment
- the comparison can end in "no upgrade" without hand-waving

## Gate C — Profile split must be operator-safe

Operators must always know whether a node is:

- baseline only
- staging candidate
- rolled back to baseline

### Required signs
- explicit profile naming
- explicit config diff between baseline and candidate
- rollback is one config flip away
- no hidden candidate defaults

## Gate D — Staging harness must close the loop repeatedly

A serious candidate must support repeatable execution, not ad hoc heroics.

### Required signs
- staging prep is scripted
- evidence collection is scripted
- start / stop / rollback actions are scripted
- artifacts land in predictable paths

## Gate E — Promotion rule must be evidence-based

A tier upgrade must come from evidence, not enthusiasm.

### Required signs
- candidate-vs-baseline scorecard exists
- promotion criteria are explicit
- abort criteria are explicit
- mixed results remain classified as mixed

---

# 2. Workstreams

## Workstream 1 — Baseline Invariant Hardening

### Goal
Preserve the current real deliverable while candidate work continues.

### Tasks
1. create an explicit **baseline profile** artifact
2. create an explicit **candidate profile** artifact
3. add a human-readable config diff note between them
4. add one command that validates the intended profile before launch
5. make rollback verification part of the normal execution loop

### Deliverables
- `docs/runbooks/profile-selection.md`
- `configs/` or equivalent profile snapshots
- `scripts/check-profile-mode.sh`
- rollback verification notes tied to real artifacts

### Exit condition
An operator can answer in under 30 seconds:

> Which mode is this node in, and how do I get back to baseline?

---

## Workstream 2 — Evidence Automation Unification

### Goal
Turn validation from narrative-only reporting into repeatable evidence collection.

### Tasks
1. standardize output layout for baseline and candidate evidence bundles
2. add a small machine-readable summary file per run
3. record config snapshot, logs, timestamps, and verdict fields together
4. define one comparison note template that must be filled after each run
5. reject runs that do not produce enough evidence to compare

### Deliverables
- common bundle layout contract
- summary JSON or markdown schema
- one comparison checklist tied to the workflow
- updated evidence scripts / wrappers

### Exit condition
A future run can be compared against the previous one without re-explaining the directory structure from scratch.

---

## Workstream 3 — Generic Front/Backend Staging Harness

### Goal
Reduce candidate execution friction without pretending the project has already won the public-edge problem.

### Tasks
1. keep the harness minimal and explicit
2. separate front-side transport actions from backend runtime actions
3. make trust material generation deterministic
4. make front-side and backend-side artifacts land in separate folders
5. make failure classification obvious: transport / trust / runtime / fallback / rollback

### Deliverables
- clearer two-host bundle contract
- front artifact directory conventions
- backend artifact directory conventions
- failure-classification note in the runbook

### Exit condition
A staging run can fail cleanly while still producing usable postmortem evidence.

---

## Workstream 4 — Operator Visibility & Recovery

### Goal
Make the system easier to reason about under pressure.

### Tasks
1. define the minimum operator signals that must always exist
2. normalize the wording of acceptance / rejection reasons
3. add a concise runbook for reading candidate logs
4. add a concise rollback confirmation runbook
5. mark missing signals as blockers rather than "nice to have"

### Deliverables
- `docs/runbooks/operator-signals.md`
- `docs/runbooks/candidate-log-reading.md`
- normalized reason inventory
- rollback verification checklist linked to real logs

### Exit condition
An operator can distinguish these five states quickly:
- baseline path selected
- candidate path attempted
- candidate path accepted
- candidate path rejected
- fallback path used

---

## Workstream 5 — Promotion Scorecard

### Goal
Create a strict decision layer so the project stops drifting between architecture progress and real tier progress.

### Tasks
1. define a small scorecard with pass / mixed / fail outcomes
2. rate baseline and candidate using the same dimensions
3. keep the dimensions blunt and few
4. require a written verdict after each serious run
5. require a next action: promote / iterate / pause / rollback

### Suggested dimensions
- baseline stability preserved
- evidence quality
- operator clarity
- rollback confidence
- public-edge separation readiness
- net value vs added complexity

### Deliverables
- `docs/first-tier-promotion-scorecard.md`
- updated comparison workflow references

### Exit condition
The project can say one of the following without ambiguity:
- not ready
- candidate improved but not enough
- mixed / uncertain
- ready for narrow promotion

---

# 3. Recommended Execution Order

## Phase 4.1 — Make baseline and candidate modes impossible to confuse
Focus:
- Workstream 1
- Workstream 4

Reason:
If operators cannot tell what mode is active, every later comparison becomes noisy.

## Phase 4.2 — Make evidence bundles comparable
Focus:
- Workstream 2
- Workstream 5

Reason:
Without a comparison contract, the project will keep producing prose instead of decisions.

## Phase 4.3 — Make the staging harness operationally boring
Focus:
- Workstream 3
- Workstream 4

Reason:
If the harness itself is fragile, candidate results will stay suspect.

## Phase 4.4 — Run promotion review
Focus:
- score the candidate against the baseline
- decide whether the project earned a tier upgrade or remains second-tier

---

# 4. Anti-Drift Rules

The following should be treated as drift and pushed back:

## Drift A — Architecture inflation
More seams, more abstractions, more transport ideas, but no stronger evidence.

## Drift B — Candidate romance
Calling the candidate "stronger" because it is more interesting internally.

## Drift C — Observability debt
Adding complexity without adding reasons, signals, and rollback clarity.

## Drift D — Documentation without enforcement
Runbooks that exist but are not tied to repeatable scripts or evidence paths.

## Drift E — Baseline neglect
Letting the mainline deliverable become harder to operate while candidate work grows.

---

# 5. What Counts As Real Progress

Real progress includes:

- fewer ambiguous deployment modes
- clearer rollback
- better evidence bundles
- sharper comparison criteria
- lower staging friction
- stronger operator understanding
- preserved baseline reliability

What does **not** count by itself:

- more sophisticated internal wiring
- more protocol surface area
- more future-facing abstractions
- more optimistic wording in docs

---

# 6. Immediate Next Actions

## Next 3 concrete steps

1. add a **promotion scorecard** document so every serious run ends in a forced judgment
2. add a **profile-selection runbook** so baseline vs candidate mode is explicit
3. unify **baseline/candidate evidence bundle shape** so later runs can be compared mechanically

## Why these three first
Because they improve decision quality immediately without destabilizing the backend.

---

# 7. Final Recommendation

The fastest honest path toward first-tier status is **not** another round of backend-native protocol expansion.

It is:

- baseline discipline
- evidence discipline
- operator discipline
- promotion discipline

If the project gets those four right, it earns the right to prove a stronger tier.
If it skips them, it will keep looking advanced while staying stuck in second-tier reality.
