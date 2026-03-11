# Baseline vs Trusted-Front Candidate Comparison Report

## Status

Draft

## Validation Run Type

Before/after candidate comparison

## Date

2026-03-11

## Purpose

Compare the current embedded-TLS baseline against the first runnable trusted-front candidate path using the same Phase 4 decision logic.

This report answers a narrower but more useful question than “is the project first-tier now?”

The real question is:

> Has the trusted-front candidate already produced enough evidence to justify a tier upgrade over the baseline?

## Inputs

This report compares:
- `docs/baseline-validation-report.md`
- `docs/trusted-front-candidate-validation-report.md`
- `build/validation/baseline-20260311-104704`
- `build/validation/trusted-front-candidate-20260311-120056`
- `docs/detectability-validation-workflow.md`

---

# 1. Short Verdict

## Current result
**No tier upgrade yet**

## Why
Because the trusted-front candidate has now proven:
- runtime-path existence
- internal listener viability
- mTLS-capable shape
- candidate evidence capture readiness

But it has **not yet proven**:
- stronger public-edge posture than the baseline
- better passive public observation characteristics
- better active-probing resistance in a realistic staged deployment
- meaningful public-facing improvement large enough to justify a first-tier claim

## Bottom line
The candidate is **more real than before**, but it is **not yet stronger enough in evidence** to move the project out of the “strong second-tier practical baseline” category.

---

# 2. Comparison By Dimension

## A. Passive public observation

### Baseline
The baseline already established:
- direct backend TLS listener
- direct backend public TLS surface
- fallback-backed public behavior

### Trusted-front candidate
The candidate evidence run established:
- internal trusted-front listener exists
- mTLS-capable internal listener exists
- trusted-front ingress frame can be exercised locally

### Comparison judgment
**No meaningful public-edge upgrade proven yet**

### Why
The candidate run was still a **local internal candidate snapshot**.
It did not yet produce evidence of a stronger **public-facing** deployment posture.
It mostly proved the internal path is viable.

### Result
The project should **not** yet claim passive-observation improvement over the baseline.

---

## B. Active probing / runtime-path behavior

### Baseline
The baseline already had:
- cooldown behavior
- fallback budget enforcement
- operator-visible runtime signals
- stable smoke/runtime tests

### Trusted-front candidate
The candidate now adds:
- trusted-front path startup
- ingress frame parsing
- handoff path wiring
- internal trusted-front admission policy
- mTLS-capable internal listener shape

### Comparison judgment
**Candidate has improved path realism and trust-boundary readiness, but not yet proven stronger anti-probing behavior**

### Why
The candidate demonstrates more disciplined edge-path structure.
But the available evidence does not yet show that hostile probing from the outside becomes materially less effective.

### Result
This is an architectural and operational improvement, not yet a demonstrated public anti-probing win.

---

## C. Public-surface realism

### Baseline
The baseline currently still has the stronger directly observed public-surface evidence because:
- it was exercised end-to-end as the public-facing path
- fallback behavior was directly captured
- the result is tied to a concrete baseline report

### Trusted-front candidate
The candidate report currently proves:
- the candidate path runs
- trusted-front internal framing exists
- the internal mTLS-capable boundary exists locally

But it does **not yet** prove:
- a more believable public-facing edge than baseline
- a stronger external fallback/public surface

### Comparison judgment
**Baseline still has stronger publicly validated realism evidence**

### Result
The candidate has not yet overtaken baseline on this dimension.

---

## D. Operator visibility

### Baseline
Already strong.

### Trusted-front candidate
Now also strong enough to be promising because it has:
- trusted-front source evaluation
- handoff reason visibility
- admission policy reason visibility
- candidate evidence capture workflow

### Comparison judgment
**Near parity, with candidate improving edge-path observability readiness**

### Why
The candidate is now catching up on observability, but this is not the same as proving stronger public camouflage.

---

## E. Rollback / deployment safety

### Baseline
Still simpler and more proven.

### Trusted-front candidate
Now has:
- explicit rollback planning
- explicit trusted-front listener toggles
- candidate path that stays opt-in

### Comparison judgment
**Candidate readiness improved, but baseline remains safer and more mature**

### Result
The candidate has not yet displaced baseline as the mainline operational posture.

---

# 3. What The Candidate Has Successfully Changed

The candidate has successfully upgraded the project from:
- “trusted-front is mostly architecture preparation”

to:
- “trusted-front is now a runnable candidate path with evidence capture support”

That is real progress.

## Specifically achieved
- trusted-front source path is real
- ingress frame exists
- session bootstrap path exists
- service listener path exists
- trust-boundary gate exists
- mTLS-capable internal listener shape exists
- candidate evidence can be collected repeatedly

This is a major readiness improvement.

---

# 4. What The Candidate Has NOT Yet Changed

The candidate has **not yet** changed the project’s external tier ranking.

## Not yet demonstrated
- stronger public-edge camouflage than baseline
- stronger passive public posture than baseline
- stronger real-world staging behavior over two hosts
- first-tier equivalence with leading front-separated/browser-like systems

This is the key restraint the project should keep.

---

# 5. Current Tier Judgment

## Current best description
The project is still best described as:

# **Strong second-tier practical baseline**

with:

# **a materially real trusted-front candidate runtime path**

## Why not first-tier yet
Because first-tier claims require more than internal candidate maturity.
They require evidence that the **public-facing edge posture** has materially improved.

That evidence does not exist yet.

---

# 6. Comparison To Mainstream Technologies (Updated)

## Compared with ordinary Trojan/TLS-class deployments
The project is now:
- still competitive
- still often better engineered operationally
- increasingly better prepared for stronger edge evolution

## Compared with first-tier front-separated / browser-like approaches
The project is:
- structurally closer than before
- but still not there

## Honest update
The candidate work narrows the **architectural gap** more than it narrows the **proven public-edge detectability gap**.

That distinction matters.

---

# 7. Decision Implication

## What should happen next
The next high-value step is not more parser-only work.

It should be:
1. a **two-host staging trusted-front candidate**
2. a **real before/after candidate vs baseline comparison**
3. the same detectability workflow applied to that stronger staging shape

## What should not happen yet
Do not yet claim:
- first-tier status
- trusted-front superiority
- production detectability advantage

---

# 8. Final Answer

## Has the project moved forward?
**Yes, materially.**

## Has the trusted-front candidate become real enough to justify continued investment?
**Yes.**

## Has the project entered the first tier yet?
**No.**

## Why not?
Because the candidate has proven **path existence and internal trust-boundary readiness**, but not yet **public-edge victory**.

## Final short version

> The project has moved from “trusted-front preparation” to “trusted-front candidate runtime reality,”
> but it is still a strong second-tier practical baseline rather than a first-tier proven public-edge system.
