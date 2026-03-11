# Reference Mainstream Trojan/TLS Comparison Report

## Status

Draft

## Validation Run Type

Reference comparison

## Date

2026-03-11

## Purpose

Compare the project’s current **embedded TLS + fallback baseline** against a reasonable reference shape for an ordinary mainstream Trojan/TLS deployment.

This report is intentionally:
- deployment-shape oriented
- decision-focused
- honest about uncertainty

It is **not** a claim of benchmark-grade superiority over every Trojan implementation.

## Comparison Rule

This comparison is between:

1. **Current project baseline**
   - embedded TLS ingress
   - fallback support
   - runtime guardrails
   - seam/runtime tests
   - operator-visible failure signals

2. **Reference mainstream Trojan/TLS deployment shape**
   - direct public TLS listener
   - password-based Trojan/TLS flow
   - optional simple web fallback or plain HTTPS cover
   - ordinary operational assumptions
   - no assumption of unusually strong observability or staged trust-boundary design

## Evidence Sources

This report relies on:
- `docs/baseline-validation-report.md`
- `docs/capability-evaluation-matrix.md`
- current smoke tests / runtime seam tests
- current config and runtime behavior already validated in-tree

It does **not** rely on packet-capture comparisons against a specific third-party binary.
That makes this report useful for direction-setting, but not a substitute for a later external lab comparison.

---

# 1. Baseline Comparison Summary

## Short answer
The current project baseline is:
- **roughly in the same detectability class** as an ordinary Trojan/TLS deployment
- **operationally stronger** in runtime guardrails and fallback discipline
- **not yet meaningfully ahead** in public-edge camouflage class

## One-line verdict

> **Compared with an ordinary mainstream Trojan/TLS deployment, the current project baseline is competitive and often operationally better, but not fundamentally in a higher camouflage tier.**

---

# 2. Comparison by Dimension

## A. Passive observation

### Current project baseline
Observed baseline behavior shows:
- direct backend TLS listener
- no trusted external front
- no ECH
- no browser-like edge behavior
- fallback/public surface exists, but the TLS face is still the backend itself

### Reference mainstream Trojan/TLS deployment
Typical deployment shape also shows:
- direct backend TLS listener
- certificate / hostname quality depends heavily on operator setup
- no automatic front separation
- no automatic first-tier public-edge disguise

### Relative judgment
**Near parity**

### Why
Both sides still primarily expose a direct backend TLS surface.
That means the current project baseline does **not** clearly jump into a stronger public-edge class just by virtue of better internal structure.

### Advantage
- **No major project advantage in raw passive camouflage class**

### Practical conclusion
If the goal is to clearly beat ordinary Trojan/TLS on passive observation alone, backend-only structure improvements are not enough.

---

## B. Active probing behavior

### Current project baseline
Current in-tree evidence already shows:
- auth failure cooldown exists
- invalid auth paths produce explainable operator signals
- fallback budget exists
- over-budget fallback is rejected with a stable reason
- malformed/incomplete TLS handshake behavior is visible and test-backed

### Reference mainstream Trojan/TLS deployment
Typical mainstream deployments often have:
- acceptable but simpler rejection handling
- less explicit operator feedback
- weaker runtime budgeting around fallback behavior
- more dependence on deployment discipline than on built-in runtime guardrails

### Relative judgment
**Project baseline: modest advantage**

### Why
The project baseline currently demonstrates stronger runtime discipline around:
- repeated auth failures
- fallback budget control
- operator-visible rejection reasons

### Limit
This does not automatically mean hostile scanners see a much weaker signature externally.
It means the system behaves more deliberately and is easier to reason about operationally.

### Practical conclusion
The project baseline is probably **better defended operationally** than many ordinary Trojan/TLS deployments, even if it is not in a different public-edge class.

---

## C. Public-surface realism

### Current project baseline
Positive baseline traits:
- fallback path exists
- fallback can return coherent content
- plain HTTP / fallback story is part of the baseline design
- fallback slot protection helps avoid uncontrolled fallback abuse

### Reference mainstream Trojan/TLS deployment
Typical mainstream deployments vary a lot:
- some have believable fallback sites
- some have shallow or placeholder HTTPS cover
- some rely too much on “TLS exists, therefore it looks normal”

### Relative judgment
**Project baseline: slight advantage, but deployment-dependent**

### Why
The current project treats fallback as a first-class runtime concern rather than an afterthought.
That is valuable.

### Limit
A mainstream deployment backed by a very believable real web property can still look better than a weakly configured fallback here.

### Practical conclusion
The project has a **good structural fallback story**, but realism quality still depends on how the operator deploys the fallback backend.

---

## D. Operator visibility

### Current project baseline
Current strengths include:
- explicit runtime metrics
- fallback counters
- auth failure cooldown logging
- fallback rejection logging
- seam/smoke tests that already encode expected behaviors

### Reference mainstream Trojan/TLS deployment
Ordinary deployments often prioritize “it works” over:
- built-in observability
- stable rejection semantics
- operator-facing explanation of fallback/auth behavior

### Relative judgment
**Project baseline: clear advantage**

### Why
This is one of the project’s strongest current differentiators.
It is not only deployable; it is increasingly explainable.

### Practical conclusion
This project is easier to operate and reason about than a bare-minimum Trojan/TLS deployment class.

---

## E. Deployment simplicity

### Current project baseline
Strengths:
- still reasonably simple
- rollback remains straightforward

Costs:
- more runtime features to understand
- more configuration and operational concepts than the simplest baseline deployments

### Reference mainstream Trojan/TLS deployment
Strengths:
- often simpler to describe and deploy at the absolute minimum level

### Relative judgment
**Reference mainstream baseline: slight simplicity advantage**

### Why
A plain Trojan/TLS deployment with minimal extras is hard to beat on raw simplicity.

### Practical conclusion
The current project should not try to win the “smallest possible setup” contest.
It should win on better disciplined behavior at still-acceptable complexity.

---

## F. Rollback simplicity

### Current project baseline
Strengths:
- embedded TLS remains the default posture
- external-front work stays opt-in
- rollback posture is already a first-class concern in the docs and direction

### Reference mainstream Trojan/TLS deployment
Typical mainstream deployments are simple to roll back partly because they have fewer staged modes.

### Relative judgment
**Near parity, with project advantage in explicitness**

### Why
The project baseline is not necessarily simpler, but it is more explicit about rollback assumptions.

---

# 3. Decision-Oriented Comparison Table

| Dimension | Current Project Baseline | Reference Mainstream Trojan/TLS | Relative Judgment |
|---|---|---|---|
| Passive public posture | Direct backend TLS surface | Direct backend TLS surface | Near parity |
| Active probing discipline | Cooldown + fallback budget + stable failure semantics | Usually simpler / less instrumented | Project modestly ahead |
| Fallback/public realism | Structurally strong, deployment-dependent | Varies a lot by deployment | Project slightly ahead in structure |
| Operator visibility | Stronger than usual baseline class | Usually weaker | Project clearly ahead |
| Deployment simplicity | Good, but not minimal | Often slightly simpler | Reference slightly ahead |
| Rollback clarity | Strong and explicit | Usually simple, less formalized | Near parity / project explicitness edge |

---

# 4. Final Assessment

## What the comparison says
The project is currently best described as:
- **a stronger-engineered mainstream Trojan/TLS baseline**
- not yet a first-tier public-edge camouflage system
- stronger in operator discipline than in raw public-edge disguise

## What it does better than ordinary mainstream Trojan/TLS
- fallback is treated more seriously
- runtime guardrails are stronger
- rejection behavior is more observable
- test coverage is more aligned with real operational failure cases

## What it does not yet clearly beat
- passive public-edge camouflage class
- first-tier front-separated behavior
- browser-like or edge-layer realism

## Practical conclusion
If the comparison target is **ordinary Trojan/TLS-class systems**, the current project is competitive and often operationally ahead.

If the comparison target is **first-tier public-edge camouflage systems**, this comparison changes very little: the project is still behind until it gains a real trusted-front deployment shape.

---

# 5. Direction Implication

This report supports the current Phase 4 decision:

> **Mainline = strong Trojan/TCP/TLS baseline**
> **Alignment = trusted external front for first-tier posture**

That remains the right split because:
- the current baseline already competes well inside its class
- the next real gains do not come from more backend-only polish alone
- the next real gains likely come from edge separation and deployment shape

---

# 6. Recommended Next Action

The next high-value comparison should be:
1. a **trusted-front staging candidate** against the current baseline
2. using the same detectability validation workflow
3. with before/after evidence tied to staging topology and rollback readiness

That is the comparison that can actually tell whether the trusted-front path is earning its extra operational cost.
