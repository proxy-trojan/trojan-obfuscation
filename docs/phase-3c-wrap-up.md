# Phase 3C Wrap-Up

## Status

This Phase 3C slice is complete in a structurally meaningful sense.

It chose and implemented the current project direction as:
- **external front / ECH-ready edge preparation**
- **not** QUIC ingress as the immediate next path
- **not** a transport rewrite

The current baseline remains:
- `feature_1.0_no_obfus_and_no_rules`

## What Phase 3C Achieved

### Direction choice
Phase 3C explicitly chose:
- trusted external-front preparation
- explicit trust-boundary shaping
- internal-only handoff wiring first

It explicitly deferred:
- QUIC ingress
- backend-native ECH
- broad transport-adapter abstraction
- real public rollout

### Implemented seams and boundaries
Phase 3C now has the following concrete pieces in code:
- `ExternalFrontMetadataProvider`
- provider-driven `Service` integration
- provider injection decision + observability hooks
- `ExternalFrontHandoff`
- `ExternalFrontHandoffContract`
- `TrustedInternalHandoffInput`
- `TrustedInternalHandoffInputContract`
- `ExternalFrontHandoffBuilder`
- `ConfigTrustedInternalHandoffSourceStub`
- operator-visible handoff rejection / apply reasons
- seam-level tests for the above boundaries

## What Changed in Practice

Before this Phase 3C slice, external-front work was mostly:
- documentation
- trust-policy shaping
- ingress-selection preparation
- test-only metadata ideas

After this Phase 3C slice, the codebase now has a default-off, internal-only path that can flow through:
- source stub
- input contract
- handoff builder
- handoff contract
- service integration
- session runtime ingress selection

This means external-front is no longer only a design posture.
It is now a controlled internal wiring path with explicit acceptance/rejection semantics.

## Current Ingress / Protocol Shape

### Ingress architecture kinds
At the architecture level, the project now distinguishes three ingress kinds:
1. `embedded_tls`
2. `external_front`
3. `future_quic` (reserved / deferred)

### Current external-front source kinds
Within the current `external_front` preparation path, the code now distinguishes:
1. `test_injected_external_front`
2. `trusted_internal_handoff`

### Current protocol reality
The only fully delivered and production-shaped protocol family remains:
- **Trojan over TCP/TLS**

External-front support is now:
- structurally real in code
- default-off
- internal-only
- not yet a real trusted-front deployment path

QUIC remains:
- deferred
- not implemented as a live ingress path

## Deployment / Rollout Posture

The current posture matches **Stage 1 — Controlled internal wiring only**.

That means:
- embedded TLS remains the default ingress
- external-front mode remains disabled by default
- internal testing and code-path staging are possible
- real deployment behind a trusted front is still deferred

## Done Criteria Met

This Phase 3C slice should be considered complete because:
- builds are green
- smoke tests are green
- runtime seam tests are green
- embedded-TLS default behavior remains intact
- external-front remains default-off
- source/build/handoff/apply boundaries are explicit
- trusted-internal and test-injected paths are no longer mixed together implicitly
- rejection reasons are operator-visible at the current seam level

## What Is Intentionally Deferred

The following are intentionally not required for this Phase 3C slice to count as complete:
- real trusted metadata source integration
- production trust-boundary transport
- canary rollout behind a real front
- QUIC ingress
- HTTP/3 Trojan transport
- backend-native ECH
- WebSocket / gRPC transport modes
- transport-adapter interface hierarchy rollout

## Recommended Next Step

The recommended next step is **not** more runtime expansion by default.

Preferred options from here:
1. treat this slice as complete and stop
2. document any remaining operator-facing notes
3. only then consider a narrow real trusted metadata source integration

## Final Verdict

Phase 3C should currently be considered:
- **architecturally successful**
- **implemented enough to stage safely in code**
- **not yet ready for broad real deployment**

That is an acceptable and healthy stopping point.
