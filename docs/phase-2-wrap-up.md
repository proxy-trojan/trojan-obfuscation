# Phase 2 Wrap-Up

## Status

Phase 2 is complete in a structurally meaningful sense.

- **Phase 2A** established modular control-flow and supporting service abstractions.
- **Phase 2B** established boundary types and execution seams around the server session path.

The current baseline remains:

- `feature_1.0_no_obfus_and_no_rules`

## What Phase 2 Achieved

### Phase 2A
Extracted and stabilized foundational modules:
- `RuntimeMetrics`
- `AbuseController`
- `FallbackController`
- `OutboundDialer`
- `SessionGate`

### Phase 2B
Reshaped the server-side session path around explicit boundaries:
- `SessionContext`
- `ConnectTarget`
- `EmbeddedTlsInbound`
- `RelayExecutor`
- `RelayExecutionPlan`
- `SessionAdmissionRuntime`
- `SessionLifecycleRuntime`

Also completed:
- clearer TCP relay startup seam
- explicit execution-plan driven session dispatch
- split shutdown steps inside `ServerSession`
- CI-consistent default build posture for MySQL (`ENABLE_MYSQL=OFF` by default)

## What Changed in Practice

Before Phase 2B, `ServerSession` handled too many concerns inline:
- transport edge semantics
- admission side effects
- relay decision interpretation
- outbound dialing startup
- lifecycle bookkeeping
- shutdown cleanup sequencing

After Phase 2B, `ServerSession` is much closer to a runtime host that:
- receives inbound bytes
- delegates edge/admission/relay planning
- executes a plan
- owns runtime forwarding loops
- orchestrates final shutdown steps

## What Is Intentionally Deferred

The following items are intentionally not required for Phase 2 completion:
- QUIC ingress implementation
- ECH implementation
- transport adapter hierarchy rollout
- full `Service` refactor
- cross-session unified shutdown framework
- deep UDP runtime redesign

These belong to a later phase if they are still valuable.

## Suggested Next-Phase Candidates

If the project continues beyond Phase 2, the most natural next candidates are:
1. UDP runtime cleanup and clearer UDP execution boundaries
2. `Service` slimming and session-construction cleanup
3. optional cross-session shutdown helper extraction
4. future-facing ingress experiments (QUIC / external edge / ECH-ready front)

## Done Criteria

Phase 2 should be considered done when:
- builds are green
- smoke tests are green
- the main server session path is structured around explicit boundaries rather than inline orchestration blobs
- future transport/edge work can be added without first re-opening a monolithic `ServerSession`

That bar is now met.
