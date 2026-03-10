# Phase 3C Rollout Note

## Status

Draft

## Purpose

Describe how external-front support should be enabled in practice without destabilizing the current embedded-TLS baseline.

This note focuses on:
- enablement stages
- rollout constraints
- rollback expectations
- observability requirements
- operator-facing safety rules

It is intentionally separate from the handoff-contract and integration-note documents.

---

# 1. Default Posture

## Required default
External-front mode must remain **disabled by default**.

That means:
- the embedded TLS path remains the default ingress
- deployments do not accidentally change behavior by upgrading binaries alone
- external-front logic enters runtime behavior only through an explicit config change

## Why this is required
The current codebase now contains:
- external-front context types
- trust policy
- validation results
- context shaping logic
- ingress selection seam
- observability skeleton

But it still does **not** include a full production front-source integration path.

Default-off protects the current stable baseline while the integration model matures.

---

# 2. Rollout Stages

## Stage 0 — Documentation and seam preparation
Already completed or in progress:
- handoff contract draft
- capability comparison
- trust-policy skeleton
- ingress-selection seam
- config gate
- observability skeleton

This stage should not alter production behavior.

## Stage 1 — Controlled internal wiring only
Allow internal testing of external-front context injection in code or test harnesses only.

Rules:
- no public deployment dependency yet
- no assumption of a real external proxy in production
- no implicit metadata source acceptance

Success condition:
- trusted and rejected paths are explainable through logs/tests
- embedded TLS behavior remains unchanged when external-front mode is disabled

## Stage 2 — Canary backend enablement behind a trusted front
Only after a real trusted metadata source exists.

Rules:
- enable on a limited canary environment only
- require explicit trusted-front deployment assumptions
- verify operator visibility before broader exposure

Success condition:
- canary traffic confirms that accepted/rejected front metadata behavior matches design
- rollback is one config change away

## Stage 3 — Broader deployment evaluation
Only after canary observations are stable.

Rules:
- do not expand rollout only because the code path exists
- require operational confidence in logs, metrics, and trust behavior
- preserve an easy path back to embedded-TLS-only mode

---

# 3. Required Enablement Conditions

External-front mode should not be enabled in a real deployment unless all of the following are true:

## Condition A — Trusted metadata source exists
There must be a real, operator-controlled upstream source for external-front metadata.

## Condition B — Trust boundary is explicit
The backend must know why the metadata is trustworthy.
Examples:
- mutually authenticated internal TLS
- loopback / unix socket boundary
- tightly allowlisted internal network segment with explicit control assumptions

## Condition C — Reject reasons are observable
Operators must be able to distinguish at least:
- external front disabled
- external front trusted
- external front rejected
- validation failure reason

## Condition D — Rollback is immediate
Disabling `external_front.enabled` must cleanly restore the embedded-TLS default path.

## Condition E — Baseline tests remain part of rollout
Smoke tests and seam tests must still pass before rollout changes are accepted.

---

# 4. Rollback Strategy

## Primary rollback
Set:
```json
{
  "external_front": {
    "enabled": false
  }
}
```

This must restore embedded-TLS default selection.

## Rollback expectations
A rollback should:
- stop selecting the external-front path
- stop trusting front-provided metadata
- preserve normal embedded-TLS operation
- avoid requiring a transport redesign or code revert

---

# 5. Observability Requirements

Before real rollout, operators should be able to see:

## Minimum event classes
- embedded TLS default path selected
- external-front mode disabled
- external-front metadata trusted
- external-front metadata rejected

## Minimum rejection visibility
At least one stable reason string should be available, for example:
- `missing_trusted_front_id`
- `missing_original_client_identity`
- `missing_verified_tls_termination`

## Why this matters
Without explainable observation, external-front rollout becomes difficult to debug and unsafe to expand.

---

# 6. What Not To Do During Rollout

## Do not
- enable external-front mode on all nodes as the first real deployment step
- assume a metadata source is trustworthy because it is convenient
- mix QUIC experimentation into the same rollout step
- remove or weaken embedded-TLS coverage during rollout
- silently accept partially trusted metadata

---

# 7. Practical Operator Guidance

## Good first use case
A tightly controlled staging or canary environment where:
- the upstream front is operator-controlled
- metadata origin is well understood
- rejection reasons can be inspected easily

## Bad first use case
A public production rollout where:
- metadata provenance is still informal
- no trusted-front transport or validation story exists
- no one is watching rejection reasons or fallback behavior

---

# 8. Current Recommendation

Treat external-front mode as:
- **implemented enough to stage safely in code**
- **not yet ready for broad default deployment**

The next steps should preserve that posture.

## Recommended order from here
1. keep default-off behavior
2. improve runtime observability hooks
3. only then consider a narrow real metadata source integration
4. only after that evaluate canary rollout
