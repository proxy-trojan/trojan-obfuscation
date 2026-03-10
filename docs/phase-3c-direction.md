# Phase 3C Direction Decision

## Status

Proposed

## Recommendation

Choose **external front / ECH-ready edge preparation** as the default Phase 3C direction.

Do **not** treat UDP service-flow cleanup as a mandatory Phase 3B.5 prerequisite unless the next chosen direction becomes UDP-heavy (for example, QUIC ingress).

## Context

The project has already completed the structural work needed to make this decision on real code rather than speculation:

- **Phase 2** finished the main session-boundary work and documented the result in `docs/phase-2-wrap-up.md`.
- **Phase 3A** improved UDP/runtime clarity and added `runtime_seam_tests` with direct coverage for runtime seams.
- **Phase 3B first-round cleanup** reduced `Service` duplication by introducing:
  - `create_server_session(...)`
  - `create_session(...)`
  - `AcceptDecision`
  - `evaluate_incoming_connection(...)`
  - `handle_accept_completion(...)`

Current architecture now has enough explicit seams to support a future-facing direction choice.

## Options Considered

### Option A — Continue runtime stabilization

Keep focusing on cleanup and testing rather than future ingress work.

**Pros**
- lowest implementation risk
- easiest to keep baseline stable
- low operational surprise

**Cons**
- postpones meaningful future-facing architecture work
- diminishing returns after Phase 3A and Phase 3B first-round cleanup

### Option B — QUIC ingress preparation

Use the next phase to move toward a UDP-native ingress path.

**Pros**
- strategically interesting
- aligns with future modern transport experimentation
- may unlock a different front-door architecture

**Cons**
- drags the project back into UDP transport complexity immediately
- makes `Service::udp_async_read()` and related UDP service flow much more important to clean first
- increases implementation and operational risk substantially
- does not align with the current lowest-risk seam evolution path

### Option C — External front / ECH-ready edge preparation

Use the next phase to prepare the codebase for a trusted external edge / front-door model while keeping the backend session path relatively stable.

**Pros**
- best matches the current seam evolution (`EmbeddedTlsInbound`, `SessionContext`, relay/admission seams)
- avoids reopening UDP-heavy transport complexity too early
- creates a path toward future edge experiments without forcing QUIC now
- keeps backend responsibilities focused on admission, relay, and runtime hosting

**Cons**
- does not immediately deliver a new transport implementation
- requires careful trust-boundary design between front and backend
- may require clearer metadata contracts before implementation begins

## Decision

Choose **Option C: external front / ECH-ready edge preparation**.

## Why This Is The Right Next Step

1. **It best fits the current architecture.**
   The codebase now has explicit boundaries around inbound evaluation, admission, relay planning, and runtime ownership. Those are better foundations for an external edge handoff than for an immediate QUIC jump.

2. **It avoids forcing a premature UDP-heavy cleanup.**
   `Service::udp_async_read()` is now the next clear density hotspot, but it is not severe enough to justify a cleanup round by default. It only becomes a likely prerequisite if the next direction is explicitly UDP/QUIC-heavy.

3. **It preserves momentum without reopening the wrong layer.**
   The current baseline is now clean enough that Phase 3C should move the architecture forward rather than continuing internal cleanup by inertia.

4. **It keeps future options open.**
   Choosing an external-front direction now does not eliminate a later QUIC path. It simply avoids paying that complexity cost before there is a concrete reason.

## Explicitly Deferred

The following are intentionally not the default next steps:

- QUIC ingress implementation
- mandatory Phase 3B.5 UDP service-flow cleanup
- standalone `SessionFactory` / `AcceptGate` module extraction
- transport-adapter hierarchy rollout
- full ECH implementation

## Recommended Phase 3C Scope

Phase 3C should begin with architecture and boundary definition, not with a transport rewrite.

### 3C.1 Define the trusted external-front handoff contract

Document what metadata may be handed from the front layer to the backend, for example:
- original client address
- SNI / ALPN-derived context
- ingress mode / transport metadata
- any future edge hints that are safe and necessary

### 3C.2 Introduce an explicit external-front boundary type

Prefer a concrete seam over a speculative interface hierarchy.

Good likely candidates:
- `ExternalFrontContextBuilder`
- or `ExternalFrontInbound`

The goal is to produce the same downstream style of input already used by the admission path, rather than inventing a parallel stack.

### 3C.3 Define trust and validation rules

An external front must not become an implicit trust sink.

Minimum concerns:
- who is allowed to send front-provided metadata
- how the backend verifies trusted-front origin
- what happens when metadata is missing or inconsistent

### 3C.4 Add narrow tests around the new boundary

Do not wait until a full implementation exists.
Start with contract-level and validation-level tests.

## Decision Rule For Reopening UDP Cleanup

If the chosen Phase 3C direction later changes to a **UDP-heavy path** (especially QUIC ingress), then a narrow **Phase 3B.5** is justified before implementation.

That cleanup should stay small and focus on:
- UDP session lookup/cleanup seam
- UDP session construction seam
- UDP dispatch helperization

It should not become another open-ended refactor round.

## Final Verdict

- **Recommended now:** external front / ECH-ready edge preparation
- **Not recommended now:** QUIC ingress as the immediate next phase
- **Conditional future step:** do Phase 3B.5 only if the next concrete direction becomes UDP/QUIC-heavy
