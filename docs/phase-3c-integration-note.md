# Phase 3C Integration Note

## Status

Draft

## Purpose

Describe how the current external-front design work should be integrated into the real backend path **without destabilizing the current embedded TLS baseline**.

This note is intentionally implementation-oriented.
It focuses on rollout order, failure behavior, and integration boundaries.

---

# 1. Current Code State

The codebase now has the following external-front building blocks:

- `ExternalFrontContext`
- `ExternalFrontInbound`
- `ExternalFrontTrustPolicy`
- `ExternalFrontValidationResult`
- external-front seam tests in `runtime_seam_tests`

The current state is therefore:
- **documented**
- **boundary-shaped**
- **trust-aware**
- **tested at seam level**

But it is **not yet connected to live traffic paths**.

---

# 2. Integration Goal

The next real integration goal is **not** to add a new transport implementation immediately.

The goal is to make the backend capable of accepting a future trusted external-front handoff while preserving:
- current embedded TLS behavior
- current server-side admission behavior
- current fallback behavior
- current test stability

---

# 3. Recommended Integration Order

## Step 1 — Keep embedded TLS as the default path

Do not replace or weaken the existing embedded TLS path.

The current baseline should remain:
- default
- tested
- deployable

External-front support should be added as an **additional ingress mode**, not a rewrite.

## Step 2 — Introduce an explicit ingress selection point

Before any live external-front behavior is added, the backend should gain one narrow selection point that decides whether a request is entering through:
- embedded TLS
- external front
- future ingress mode(s)

This should be a small integration seam, not a general interface hierarchy.

Likely shape:
- one explicit ingress-mode decision point
- one concrete path for embedded TLS
- one concrete path for external-front evaluation

## Step 3 — Fail closed on untrusted front metadata

If external-front metadata is present but fails validation, the system must not silently treat it as trustworthy.

Minimum expected behavior:
- no trusted client identity should be propagated
- no trusted transport hints should be propagated
- logs / metrics should be able to distinguish the rejection reason later

## Step 4 — Start with conservative runtime behavior

The first live integration should keep fallback behavior conservative.

That means:
- if trusted-front metadata is invalid, do not invent partial trust
- do not attempt mixed trust models on the first rollout
- prefer dropping to conservative context shaping or rejecting the handoff path rather than accepting ambiguous metadata

## Step 5 — Add integration tests before rollout expansion

Once the external-front path touches live routing, add tests that cover:
- trusted metadata path
- invalid metadata path
- missing metadata path
- ALPN override behavior under trusted metadata
- fail-closed behavior when trust validation fails

---

# 4. Hard Requirements Before Live-Path Wiring

The following must be true before external-front code is allowed into the real runtime path:

## Requirement A — Explicit ingress selection
No implicit "if metadata exists, maybe external-front" logic.

## Requirement B — Explicit trust validation
No blind use of front-provided metadata.

## Requirement C — Clear fail-closed semantics
A rejected front context must not partially contaminate trusted downstream fields.

## Requirement D — Logging and operability hooks
Operators must be able to distinguish:
- trusted external-front path used
- external-front metadata rejected
- external-front metadata missing
- fallback path selected normally

## Requirement E — Embedded TLS baseline preserved
No regression to the existing default deployment path.

---

# 5. Recommended First Live Integration Shape

The first live integration should stay narrow.

## Good first live target
Add one integration seam that allows a backend-owned caller to choose between:
- `EmbeddedTlsInbound`
- `ExternalFrontInbound`

The goal is only to prove that downstream admission and relay logic can accept either path shape.

## Not a good first live target
- full front proxy implementation
- ECH implementation
- QUIC implementation
- dynamic multi-front trust ecosystem
- automatic detection of untrusted pseudo-front metadata from arbitrary peers

---

# 6. Failure Behavior Rules

## Trusted metadata passes validation
- downstream context may use original client identity
- downstream context may use trusted transport hints
- admission path continues normally

## Trusted metadata fails validation
- do not propagate trusted metadata fields
- either reject the handoff path or fall back to conservative context shaping, depending on the integration point
- do not silently reinterpret invalid metadata as trustworthy

## External-front metadata is absent
- embedded TLS-compatible path remains valid
- no assumption that an external front exists

## External-front metadata is inconsistent
Examples:
- `metadata_verified=true` but no `trusted_front_id`
- front claims transport hints without trusted termination

Required response:
- fail closed for trusted fields
- do not partially trust inconsistent metadata

---

# 7. What Not To Do Next

## Do not
- connect the new external-front types directly into the main runtime path in one large patch
- introduce a generalized inbound-adapter hierarchy yet
- combine transport redesign with trust-model rollout
- mix QUIC experimentation into the same integration step
- weaken embedded TLS tests in order to land external-front code faster

---

# 8. Recommended Next Coding Step

The best next code step is:

## Introduce a narrow backend ingress-selection seam

That seam should:
- choose which concrete inbound path is used
- keep downstream admission and relay code unchanged as much as possible
- preserve embedded TLS as the default and safest path

This is the smallest meaningful bridge between the current Phase 3C skeleton work and real runtime integration.

---

# 9. Final Integration Verdict

The project is **ready for the next design-to-runtime transition step**, but only under these constraints:
- embedded TLS remains the default baseline
- trust validation remains explicit and fail-closed
- integration is staged, not a one-shot rewrite
- external-front support enters through a narrow selection seam rather than a broad abstraction layer
