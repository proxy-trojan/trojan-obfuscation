# Two-Host Trusted-Front Staging Execution Plan

## Status

Prepared

## Purpose

Translate the trusted-front candidate from a local runnable path into a minimal two-host staging execution plan.

This plan is the next step after the local candidate evidence run.
It exists to close the remaining gap between:
- local candidate proof
- real staged trust-boundary validation

## Goal

Stand up the smallest meaningful two-host staging deployment that can answer:

> Does the trusted-front candidate improve the project’s position enough to justify continued mainline investment?

## Topology

### Host A — Trusted front
Responsibilities:
- accept public-facing traffic
- establish the internal trusted boundary to Host B
- present the candidate public-edge posture under evaluation
- transmit trusted-front envelope + downstream payload to Host B

### Host B — `trojan-obfuscation` backend
Responsibilities:
- run the current baseline public listener (optional during comparison)
- run the internal trusted-front listener
- enforce trusted-front admission policy
- terminate the internal mTLS listener
- continue using fallback behavior and runtime guardrails

### Internal boundary
The first staging target should use:
- **mTLS-protected internal hop**

This is the minimum acceptable real trust story for the next step.

---

# 1. Preconditions

Before starting execution, all of the following should be true:

- [ ] `docs/trusted-front-staging-topology.md` exists and is current
- [ ] `docs/trusted-front-rollout-checklist.md` exists and is current
- [ ] `docs/trusted-front-rollback-checklist.md` exists and is current
- [ ] local candidate evidence has been captured successfully
- [ ] baseline evidence exists for comparison
- [ ] candidate path has mTLS-capable listener shape
- [ ] candidate path remains opt-in and rollback-friendly

## Current state
As of 2026-03-11, these preconditions are effectively met for **execution preparation**, but not yet for claiming a staging result.

---

# 2. Minimum Execution Scope

The first two-host staging attempt should be intentionally narrow:

- one trusted front host
- one backend host
- one backend candidate deployment
- one internal mTLS boundary
- one evidence capture cycle
- no fleet rollout
- no public production traffic claims

## Explicit non-goals
- no canary expansion yet
- no QUIC
- no ECH
- no browser-like edge emulation claims
- no “first-tier” marketing language

---

# 3. First Execution Sequence

## Step 1 — Prepare shared trust material
Generate:
- staging CA
- backend trusted-front listener cert/key
- front client cert/key

## Step 2 — Prepare backend candidate config
Enable:
- `external_front.enabled = true`
- `enable_trusted_front_listener = true`
- `trusted_front_listener_use_mtls = true`
- loopback restriction should be relaxed **only if** the two-host internal path is explicitly trusted and documented

## Step 3 — Prepare front transport adapter
The front host must be able to send:
- trusted-front envelope
- downstream payload
- over the internal mTLS-protected hop

## Step 4 — Capture candidate evidence
Collect:
- public passive observation notes
- active probing notes
- internal listener behavior
- operator logs
- rollback confirmation

## Step 5 — Compare against baseline
Use the same dimensions as the baseline and candidate workflow.

---

# 4. Required Outputs

A serious two-host staging run should produce:
- `two-host trusted-front config bundle`
- candidate evidence bundle
- candidate-vs-baseline comparison notes
- rollback notes
- operator issues / friction list

---

# 5. Success Criteria

The two-host staging attempt only counts as a success if it shows all of the following:
- trusted-front candidate still works outside single-host harnessing
- internal mTLS boundary behaves as expected
- operator-visible signals remain understandable
- rollback remains clean
- candidate plausibly improves the public-edge story enough to justify more work

## Important clarification
“Works on two hosts” is necessary, but not sufficient.
The run must also show the candidate is becoming worth the added complexity.

---

# 6. Failure Criteria

The staging attempt should be considered a failure or pause point if:
- trust assumptions become fuzzy
- two-host setup becomes operationally fragile
- candidate does not produce a better public-edge story than baseline
- rollback becomes materially harder
- operators cannot quickly tell what path is active

---

# 7. Recommended Immediate Tooling

To prepare the first two-host staging run, the project should have:
- trust-material generation helper
- backend candidate config template
- front transport placeholder notes
- evidence capture checklist for the two-host run

## Practical recommendation
The very next artifact after this plan should be:
- a small script that prepares a two-host staging bundle

That keeps the next step operational rather than theoretical.

---

# 8. Final Recommendation

The project is ready to move from:
- local candidate runtime evidence

to:
- **two-host trusted-front staging execution preparation**

It is still **not** ready to claim first-tier status.
But it is now ready to test whether such a claim could become evidence-based in the next stage.
