# Trusted-Front Staging Topology

## Status

Draft

## Purpose

Define the minimum staging topology for evaluating the project’s trusted-front direction without destabilizing the current deployable baseline.

This document is intentionally about:
- staging only
- trust-boundary clarity
- rollback safety
- operator comprehension

It is **not** a production rollout guide.

## Why This Topology Exists

The project’s current mainline value still comes from:
- Trojan over TCP/TLS
- embedded TLS ingress
- fallback-backed baseline deployment simplicity

At the same time, the project’s chosen alignment direction is:
- stronger public-edge posture through a trusted external front

The goal of this staging topology is to create the **smallest realistic environment** where that direction can be tested without pretending it is production-ready.

---

# 1. Topology Goal

The staging topology should prove four things:

1. the public edge can be separated from the backend
2. the backend can accept trusted-front metadata only under explicit trust assumptions
3. operators can observe accepted, rejected, and fallback behaviors clearly
4. rollback back to embedded-TLS-only mode is easy and immediate

If the topology cannot prove those four things, it is not good enough for Stage 2 canary work.

---

# 2. Minimum Recommended Shape

## Logical layout

```text
[Client / Probe]
        |
        v
[Trusted Front / Edge]
        |
  (trusted internal boundary)
        |
        v
[trojan-obfuscation backend]
        |
        v
[fallback backend / application]
```

## Roles

### Public Edge / Trusted Front
Responsibilities:
- terminates the public-facing edge behavior
- produces metadata intended for the backend
- forwards traffic to the backend across a trusted internal boundary
- exposes the public-facing camouflage posture being evaluated

### Backend (`trojan-obfuscation`)
Responsibilities:
- remains the relay/admission core
- validates or rejects front-provided metadata
- preserves embedded-TLS baseline fallback path when external-front mode is disabled
- exposes operator-visible acceptance/rejection reasons

### Fallback Backend
Responsibilities:
- provides believable public-surface behavior for non-protocol or fallback-triggering traffic
- supports realism checks during validation

---

# 3. Trust Boundary Requirements

The most important part of this topology is not the number of machines.
It is the clarity of the trust boundary.

## Required property
The backend must be able to explain **why** front-provided metadata is trusted.

## Acceptable staging examples
- **mTLS-protected internal hop** between trusted front and backend
- **loopback / same-host boundary** for a strictly local PoC
- **tightly allowlisted internal network segment** with explicit operational control assumptions

## Not acceptable even in staging
- plain untrusted network forwarding with no trust explanation
- front-provided metadata accepted only because it is convenient
- “we know this IP is probably ours” without clear enforcement

## Recommended first staging choice
**mTLS-protected internal hop**

Reason:
- closest to a believable future real deployment
- explicit trust story
- easier to explain in documentation and validation reports

---

# 4. Minimum Node Layout Options

## Option A — Single-host staging

### Shape
```text
public port -> front process -> trusted internal hop -> backend process -> fallback backend
```

### Benefits
- easiest to build
- fastest feedback loop
- lowest staging cost

### Limits
- weak realism for network boundary assumptions
- easier to accidentally blur trust lines

### Best use
- first PoC only

---

## Option B — Two-host staging (recommended minimum realistic shape)

### Shape
```text
Host A: trusted front / edge
   |
   |  mTLS-protected internal hop
   v
Host B: trojan-obfuscation backend + fallback backend
```

### Benefits
- clearer trust boundary
- more realistic rollout shape
- better operator validation value

### Limits
- more deployment complexity than single-host staging
- requires stronger configuration discipline

### Best use
- preferred staging topology before any canary conversation

---

## Option C — Three-role staging

### Shape
```text
Host A: trusted front / edge
Host B: trojan-obfuscation backend
Host C: fallback backend / app
```

### Benefits
- clearest operational separation
- best for later staging realism

### Limits
- probably unnecessary as the first staging step

### Best use
- later stage only if Option B already proved useful

---

# 5. Recommended Stage-1-to-Stage-2 Transition Path

## Step 1 — Single-host logical proof
Use only to confirm:
- source metadata shape works
- operator visibility works
- rollback logic works

## Step 2 — Two-host trusted-boundary proof
Use to confirm:
- metadata trust assumptions still hold across an actual boundary
- public edge and backend are genuinely separated
- rejection reasons remain understandable

## Step 3 — Canary candidate evaluation
Only after Step 2 is stable.

---

# 6. Configuration Posture

## Required defaults
- `external_front.enabled = false` by default
- trusted-front source must be opt-in
- rollback must be one config change away

## Staging-only enablement expectation
A staging deployment should clearly separate:
- baseline mode
- external-front staging mode

Operators should never be unsure which mode a node is currently running.

## Recommended mode split
- **Baseline profile**: embedded TLS only
- **Trusted-front staging profile**: external-front enabled behind a controlled trusted boundary

---

# 7. Operator Visibility Requirements

Before this topology is considered useful, operators must be able to observe at least:
- embedded TLS default path selected
- trusted-front path attempted
- trusted-front path accepted
- trusted-front path rejected
- rejection reason
- fallback path selected

If these signals are not visible, the topology is not ready for meaningful validation.

---

# 8. Rollback Expectations

## Primary rollback
Disable the external-front path and return to embedded-TLS-only behavior.

Example expectation:
```json
{
  "external_front": {
    "enabled": false
  }
}
```

## Rollback success criteria
Rollback is successful only if:
- public traffic returns to the baseline ingress behavior
- front-provided metadata is no longer trusted
- fallback behavior remains intact
- no transport redesign or code revert is needed

---

# 9. What To Validate In This Topology

## Public-edge questions
- does the front layer look more believable than direct backend TLS?
- does it preserve consistent behavior under passive observation?

## Backend questions
- does the backend cleanly accept only trusted metadata?
- are rejection reasons stable and understandable?

## Operational questions
- can operators tell which path is active?
- can they roll back under pressure?
- can they distinguish failure in the front from failure in the backend?

---

# 10. Recommended First Implementation Shape

If a real PoC is attempted after Phase 4 gates are ready, the recommended first shape is:

## **Two-host staging with mTLS-protected trusted front**

### Why this is the best first serious shape
- preserves the current backend core
- aligns with the project’s chosen direction
- provides a real trust-boundary story
- is much more meaningful than a same-host-only demo
- still avoids jumping straight to public production complexity

---

# 11. Non-Goals For This Topology

This staging topology should not attempt to prove all of the following at once:
- production internet-scale readiness
- ECH delivery
- QUIC support
- browser-like cover traffic parity
- full anti-censorship superiority

Its purpose is narrower:
- prove the trusted-front direction is operationally coherent enough to deserve the next step

---

# 12. Final Recommendation

Use this topology rule:

> **First prove that trusted-front separation is operationally real in staging.**
> **Only then discuss canary rollout or stronger public-edge claims.**

For this project, the preferred first meaningful staging target is:
- **two hosts**
- **mTLS-protected internal boundary**
- **external-front opt-in**
- **easy rollback back to embedded TLS baseline**
