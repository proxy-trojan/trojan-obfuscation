# Trusted-Front Staging Candidate Validation Report

## Status

Prepared

## Validation Run Type

Candidate comparison / pre-execution report

## Date

2026-03-11

## Purpose

Define the first serious validation target for the project’s trusted-front direction and record how it should be judged against the current embedded-TLS baseline.

This document is intentionally a **planning/execution artifact**.
It is not a claim that the trusted-front candidate already exists in production-ready form.

## Target Candidate

- **Name:** Trusted-front staging candidate
- **Shape:** Two-host staging topology with mTLS-protected internal boundary
- **Public entry:** Trusted front / edge host
- **Backend entry:** `trojan-obfuscation` backend behind the trusted internal hop
- **Fallback behavior:** Preserved backend fallback/application surface
- **Rollback method:** Disable `external_front.enabled` and restore embedded-TLS-only path

## Comparison Target

The candidate will be judged against:
- `docs/baseline-validation-report.md`

The core question is:

> Does trusted-front separation improve public-edge posture enough to justify its additional operational cost?

---

# 1. Validation Hypotheses

## Hypothesis A — Public-edge improvement
The trusted front should make the public-facing entry less obviously equivalent to a direct backend TLS surface.

## Hypothesis B — Backend trust discipline is preserved
The backend should accept front-provided metadata only under explicit and explainable trust assumptions.

## Hypothesis C — Rollback remains simple
Trusted-front staging must still be reversible with a config-level rollback back to embedded-TLS baseline behavior.

## Hypothesis D — Operator understanding does not regress
Operators must be able to explain:
- which path was selected
- why trusted-front metadata was accepted or rejected
- whether fallback behavior was used

---

# 2. Candidate Topology Summary

## Recommended shape
```text
[Client / Probe]
        |
        v
[Trusted Front / Edge on Host A]
        |
  (mTLS-protected internal hop)
        |
        v
[trojan-obfuscation backend on Host B]
        |
        v
[fallback backend / app]
```

## Trust story
The backend should trust metadata only because:
- it came across the explicitly trusted internal boundary
- that boundary is protected by mTLS
- the source is operationally controlled and documented

## Minimum reason this shape was chosen
This is the smallest staging shape that is:
- more realistic than same-host PoC wiring
- still operationally manageable
- able to express an actual trust boundary

---

# 3. Preconditions Before Execution

The candidate should **not** be executed until all of the following are true:

- [ ] trusted-front staging topology is documented
- [ ] rollout checklist is ready
- [ ] rollback checklist is ready
- [ ] detectability validation workflow is ready
- [ ] baseline validation report exists
- [ ] baseline smoke tests are green
- [ ] runtime seam tests are green
- [ ] trusted-front source is real enough to justify staging validation
- [ ] operator-visible acceptance/rejection reasons are available

## Current precondition status
As of 2026-03-11:
- documentation preconditions: **ready**
- baseline validation evidence capture: **ready enough to proceed locally**
- trusted-front real-source readiness: **not yet ready**
- canary readiness: **not ready**

---

# 4. Evidence To Collect

## A. Passive observation
Questions:
- does the public-facing edge now look like the front rather than the backend?
- is the certificate/ALPN/public surface more believable than direct backend exposure?
- has the project actually gained public-edge separation?

## B. Active probing
Questions:
- are malformed or non-protocol requests handled more credibly at the front?
- are backend rejection semantics kept behind the trusted boundary?
- does the candidate avoid creating a new distinctive public signature?

## C. Public-surface realism
Questions:
- does the front-facing service look coherent under normal browsing-like access?
- does fallback remain believable when reached?
- are invalid and valid paths still consistent enough to avoid obvious proxy tells?

## D. Operator visibility
Questions:
- can operators still distinguish accepted/rejected trusted-front handoff events?
- can they see trusted path vs fallback path clearly?
- can they diagnose failure in the front separately from failure in the backend?

## E. Rollback behavior
Questions:
- can trusted-front mode be disabled cleanly?
- does the node return to embedded-TLS baseline behavior without code rollback?
- is rollback fast enough to use under pressure?

---

# 5. Expected Advantages Over Baseline

The candidate is only worth pursuing if it can plausibly improve at least one of these without materially hurting the others:

- public-edge realism
- passive observation posture
- separation between hostile public traffic and backend admission logic
- future path toward first-tier camouflage alignment

## Non-advantages that do not count
The following do **not** count as sufficient reason alone:
- cleaner internal architecture
- more interesting code structure
- more elegant seams
- simply having a front in front of the backend on paper

---

# 6. Expected Risks / Failure Modes

## Risk A — Fake improvement
The topology may look better architecturally without actually improving the public-facing edge posture.

## Risk B — Trust ambiguity
The front may provide metadata in a way that operators cannot clearly justify as trustworthy.

## Risk C — Operational complexity inflation
The front may add too much complexity relative to the actual gain.

## Risk D — Observability regression
The front layer may hide the wrong signals while still failing to improve public camouflage enough.

## Risk E — Rollback fragility
The candidate may become harder to disable cleanly than the docs assume.

---

# 7. Comparison Criteria Against Baseline

The candidate should be judged as:

## Improved
Only if:
- passive public posture is meaningfully better than baseline
- active probing does not become more distinctive
- operator visibility remains sufficient
- rollback remains simple

## No meaningful change
If:
- the public edge still mostly looks like direct backend behavior
- new complexity exists without a clear public-edge gain

## Worse
If:
- the public-facing surface becomes more complex but not more believable
- rollback becomes harder
- operator reasoning becomes harder
- trust assumptions become fuzzy

---

# 8. Current Readiness Judgment

## Honest status today
This candidate is **not ready for execution yet**.

### Why
Because the project currently has:
- trusted-front architecture preparation
- internal-only source shaping
- trust/input/handoff contracts
- rollout/rollback docs

But it does **not yet** have:
- a real trusted-front source implementation suitable for staging
- a live two-host candidate deployment
- evidence from actual public-edge observation of the trusted-front path

## What this means
This document should currently be treated as:
- the prepared execution target for the next serious staging step
- not as evidence that the trusted-front path has already proven its value

---

# 9. Execution Gate

This candidate should only move from “prepared” to “execute now” when both of these become true:

## Gate 1 — Technical gate
A real trusted-front metadata source exists for staging and can cross a documented trusted boundary.

## Gate 2 — Operational gate
Operators can stage, observe, and roll back the candidate without guesswork.

If either gate is false, the candidate should remain in planning.

---

# 10. Final Verdict For Planning Stage

## Current verdict
**Prepared candidate, not yet executable**

## Why
The project has now prepared enough structure and documentation to know what the right first trusted-front staging candidate should look like.

That is valuable.
But the candidate has not yet earned claims of stronger public-edge posture until a real staged deployment is executed and compared against the baseline.

## Immediate next action
- keep this report as the execution target for the first serious trusted-front staging attempt
- use baseline evidence capture tooling to standardize before/after reporting inputs
- only then consider the first real trusted-front staging PoC
