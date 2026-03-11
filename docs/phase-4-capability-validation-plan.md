# Phase 4 Capability Validation & Deployment Readiness Plan

## Status

Proposed

## Purpose

Phase 4 is not a protocol-expansion phase.

Its purpose is to shift the project from:
- structure-first refactoring
- ingress/edge preparation

into:
- capability validation
- deployment readiness
- measurable comparison against mainstream alternatives
- explicit product-direction decisions

## Why Phase 4 Exists

Phase 3C established a meaningful external-front preparation slice:
- source / input / builder / handoff / apply seams
- default-off posture
- internal-only trusted-front path
- operator-visible rejection reasons

That work is now structurally sufficient.

The next highest-value gap is no longer another runtime seam.
The next gap is whether the project can:
- evaluate its real detectability posture
- validate deployment trade-offs
- compare itself honestly with mainstream technologies
- decide which product direction deserves mainline investment

## North-Star Question

Before more protocol work is accepted, the project must answer:

> Is the main goal to be the best deployable Trojan/TCP/TLS baseline,
> or to become a stronger trusted-front / edge-ready platform?

Phase 4 exists to make that decision evidence-based rather than intuition-driven.

## Scope

### In scope
1. capability comparison against mainstream technologies
2. deployment/staging planning for trusted-front experiments
3. anti-probing / observability validation workflow
4. operator runbook and rollback design
5. explicit decision gates for what code work should happen next

### Out of scope
- QUIC ingress implementation
- backend-native ECH implementation
- public production rollout
- broad new transport families
- large interface hierarchy extraction
- more internal-only ingress seam expansion by default

## Workstreams

### Workstream A — Capability comparison

Goal:
- compare the current project honestly against mainstream alternatives

Compare against at least:
- Trojan/TLS baseline deployments
- NaiveProxy
- REALITY-style deployments
- Hysteria2 / TUIC

Use a small matrix with these dimensions:
- detectability / probe resistance
- deployment complexity
- operator burden
- performance trade-offs
- rollback simplicity

Deliverable:
- `docs/capability-evaluation-matrix.md`

### Workstream B — Staging / deployment readiness

Goal:
- define a minimal trusted-front staging topology before any real-source rollout work

Questions to answer:
- what is the trusted-front boundary?
- where does metadata originate?
- how is rollback performed?
- what assumptions must operators guarantee?

Deliverables:
- `docs/trusted-front-staging-topology.md`
- `docs/trusted-front-rollout-checklist.md`
- `docs/trusted-front-rollback-checklist.md`

### Workstream C — Detectability validation workflow

Goal:
- create a repeatable way to judge whether deployment shapes are becoming harder or easier to identify

The first version does not need full automation.

It should define:
- passive TLS-fingerprint observation checks
- active-probing behavior checks
- fallback / plain-HTTP behavior checks
- what counts as suspicious or high-signal exposure

Deliverable:
- `docs/detectability-validation-workflow.md`

### Workstream D — Product direction decision

Goal:
- decide which strategic direction deserves mainline engineering attention next

Candidate directions:
1. strengthen Trojan/TCP/TLS baseline as the main product
2. continue trusted-front / edge-ready evolution as the main product
3. freeze trusted-front as a prepared branch and return to baseline hardening

Deliverable:
- `docs/phase-4-decision-record.md`

## Allowed Code During Phase 4

Code changes during Phase 4 should be limited to support work for validation and operations, such as:
- better logging
- small observability hooks
- config clarity improvements
- minimal staging helper scripts
- validation harness support

Code changes should not default to:
- new transport features
- new ingress protocol families
- new abstraction hierarchies
- another refactor-only expansion round

## Suggested Timeline

### Week 1 — Compare and frame
- finalize the comparison matrix
- define the project north-star question
- draft the detectability workflow

### Week 2 — Stage and validate
- define trusted-front staging topology
- define rollout / rollback checklists
- identify missing operator signals

### Week 3 — Decide
- review findings
- choose the next mainline direction
- accept or defer the next protocol-facing phase

## Success Criteria

Phase 4 is successful when:
- the project has an explicit comparison with mainstream alternatives
- detectability claims are tied to a repeatable validation workflow
- trusted-front experiments have a staging/rollback plan
- operators have a clear checklist for safe enablement
- the next engineering phase is chosen explicitly, not by inertia

## Failure Modes To Avoid

### 1. Documentation without decisions
Avoid writing many notes that do not change what the team should do next.

### 2. Secret protocol expansion
Avoid smuggling a Phase 5 transport experiment into a validation phase.

### 3. Overclaiming capability
Avoid describing internal-only preparation as delivered public-facing strength.

### 4. Comparison drift
Avoid comparing against too many tools or too many metrics.
Keep the matrix small and decision-oriented.

## Recommended Exit Decisions

At the end of Phase 4, the project should choose one of these exits:

### Exit A — Return to baseline-first development
Use if the comparison shows the current Trojan/TLS baseline still has the best cost-to-value ratio.

### Exit B — Proceed to narrow real trusted-front source integration
Use only if staging, trust, and observability are convincing enough.

### Exit C — Hold trusted-front as a prepared branch
Use if the architecture is good but deployment value is not yet justified.

## Final Recommendation

Treat Phase 4 as a capability-validation phase, not a code-expansion phase.

The goal is to restore balance between:
- engineering elegance
- measurable deployment value
- product-direction clarity
