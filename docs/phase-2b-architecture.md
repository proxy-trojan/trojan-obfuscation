# Phase 2B Architecture Plan

## Purpose

Phase 2A focused on structural refactoring without changing behavior. It extracted:

- `RuntimeMetrics`
- `AbuseController`
- `FallbackController`
- `OutboundDialer`
- `SessionGate`

Phase 2B builds on that work and defines the next architectural step: make the current Trojan-Pro baseline easier to evolve toward:

- clearer edge/core boundaries
- future transport adapters
- future QUIC ingress experimentation
- future ECH-capable or web-native front integration

This document is intentionally design-first. It does **not** imply immediate large-scale rewrites.

---

## Current Baseline After Phase 2A

The current baseline remains the branch:

- `feature_1.0_no_obfus_and_no_rules`

The codebase already has the following useful separation:

### Control / observability modules
- `RuntimeMetrics`
- `AbuseController`
- `FallbackController`

### Session decision / connection modules
- `SessionGate`
- `OutboundDialer` (TCP path first)
- `EmbeddedTlsInbound`
- `RelayExecutor`
- `RelayExecutionPlan`
- `SessionAdmissionRuntime`
- `SessionLifecycleRuntime`

### Still-heavy modules
- `Service`
- `ServerSession`

These are much smaller than before, but they are still responsible for too much orchestration glue.

---

## Phase 2B Goals

### Functional goals
- preserve the current Trojan/TLS baseline behavior
- preserve current smoke/integration test coverage
- preserve current abuse-control behavior
- avoid rewriting working code paths prematurely

### Architectural goals
- define a clean **edge/core boundary**
- define a transport-facing interface that can host future adapters
- reduce coupling between session lifecycle and transport specifics
- prepare for future external front / QUIC / ECH-ready experiments

### Non-goals
- no immediate QUIC implementation
- no immediate ECH implementation inside the current OpenSSL listener
- no microservice split
- no multi-process redesign

---

## Recommended Target Shape

```text
                ┌────────────────────────────┐
                │     Edge / Front Layer     │
                │----------------------------│
                │ Embedded TLS Listener      │
                │ Future External Front      │
                │ Future QUIC Ingress        │
                └─────────────┬──────────────┘
                              │
                              ▼
                ┌────────────────────────────┐
                │     Session Admission      │
                │----------------------------│
                │ SessionGate                │
                │ AbuseController            │
                │ FallbackController         │
                └─────────────┬──────────────┘
                              │
                              ▼
                ┌────────────────────────────┐
                │        Relay Core          │
                │----------------------------│
                │ OutboundDialer             │
                │ RuntimeMetrics             │
                │ Future Route Selection     │
                │ Future Policy Layer        │
                └─────────────┬──────────────┘
                              │
                              ▼
                ┌────────────────────────────┐
                │    Outbound / Target Net   │
                └────────────────────────────┘
```

The key idea is simple:

> the current embedded TLS listener should become only one possible **edge implementation**, not the permanent center of the whole system.

---

## Edge / Core Boundary

## Edge responsibilities
The edge side should eventually own:

- incoming connection acceptance
- transport-specific handshake concerns
- transport-specific metadata extraction
- ALPN / front-side metadata
- future ECH/QUIC-facing concerns

Examples:
- current embedded TLS listener
- future QUIC ingress adapter
- future external edge that forwards into the relay core

## Core responsibilities
The relay core should own:

- session admission decisions
- authenticated vs fallback path selection
- abuse-control enforcement
- outbound dialing
- traffic forwarding lifecycle
- metrics and policy decisions

This means the relay core should avoid becoming permanently coupled to one listener implementation.

---

## Proposed New Internal Concepts

## 1. `SessionContext`
Introduce a small struct that describes the inbound session in a transport-neutral way.

Suggested shape:

```cpp
struct SessionContext {
    std::string source_ip;
    uint16_t source_port{0};
    std::string selected_alpn;
    bool tls_handshake_completed{false};
    bool is_from_embedded_tls_listener{true};
};
```

Purpose:
- provide one transport-neutral handoff object
- stop leaking transport details across too many layers

## 2. `ConnectTarget`
Represent the selected outbound destination explicitly.

Suggested shape:

```cpp
struct ConnectTarget {
    std::string host;
    uint16_t port{0};
    bool is_fallback{false};
};
```

Purpose:
- make path selection output explicit
- reduce ad-hoc `query_addr/query_port` threading

## 3. `SessionDecision`
`SessionGate` currently returns a useful result already. Over Phase 2B, it should become the explicit contract between edge/session parsing and relay execution.

Potential evolution:

```cpp
struct SessionDecision {
    enum class Path {
        AuthenticatedTcp,
        AuthenticatedUdp,
        Fallback,
        Reject
    };

    Path path;
    ConnectTarget target;
    std::string outbound_payload;
    bool authenticated{false};
    bool used_external_authenticator{false};
    std::string auth_record_password;
};
```

---

## Transport Adapter Direction

Phase 2B should not fully implement this yet, but it should shape the code so transport-specific adapters become natural.

## Proposed interface direction

```cpp
class ITransportAdapter {
public:
    virtual ~ITransportAdapter() = default;
    virtual SessionContext build_session_context() const = 0;
};
```

This is deliberately minimal.

The point is **not** to introduce a forest of abstract classes immediately.
The point is to create a clear seam so the current embedded TLS code is not assumed to be the only entry path forever.

## Recommended first concrete adapter
- `EmbeddedTlsTransportAdapter`

This can remain backed by current code paths while giving the codebase a named concept for the existing mode.

---

## Why Not Implement ECH Directly Now?

Even though ECH is now standardized, implementing it directly inside the current embedded listener is not the best next step.

Reasons:
1. current code is still evolving toward cleaner boundaries
2. ECH is not just a config flag; it needs ecosystem support around TLS stack, DNS bootstrapping, and deployment topology
3. a future **external front / edge** may be a cleaner place for ECH-related work than the current relay core

So the recommendation remains:

> prepare the architecture so an ECH-capable edge can exist later, instead of forcing ECH into the current core immediately.

---

## Why Not Implement QUIC Directly Now?

For the same reason:

- QUIC ingress is better treated as a new transport path
- not as a large mutation of the current embedded TLS/TCP listener

That means the code should first be prepared to host a second ingress model.

---

## Phase 2B Recommended Work Order

## Step 1 — Introduce neutral handoff types
Add and gradually adopt:

- `SessionContext`
- `ConnectTarget`
- a clearer `SessionDecision` contract

This is the lowest-risk Phase 2B step.

## Step 2 — Isolate embedded TLS edge semantics
Move more transport-specific context gathering into a named embedded transport boundary.

Target outcome:
- `ServerSession` no longer implicitly acts as both transport edge and core executor

## Step 3 — Define a small relay-core execution seam
Introduce a clearer boundary between:
- decision-making
- outbound dialing
- data forwarding

This does **not** need to be a giant framework. It just needs to be explicit.

## Step 4 — Choose future PoC direction
Only after the structure is ready, choose one of:

- QUIC ingress PoC
- external front / ECH-ready edge PoC
- more web-native front experimentation

---

## Decision Checkpoints

The following future checkpoints should require explicit human decision:

### Checkpoint A
Should Phase 2B stop at clearer internal boundaries, or continue to a first transport-adapter implementation?

### Checkpoint B
Should the first future-facing PoC be:
- QUIC-oriented
- external front / ECH-ready
- more web-native / Naive-inspired

### Checkpoint C
Should the existing embedded TLS listener remain the default long-term edge, or become one deployment mode among several?

---

## Current Phase 2B Progress Snapshot

The codebase has now completed the core Phase 2B structural work:

- `SessionContext` is in place and used as the transport-neutral inbound handoff.
- `ConnectTarget` is now threaded through relay execution instead of ad-hoc host/port strings.
- `EmbeddedTlsInbound` isolates embedded TLS edge semantics from `ServerSession`.
- `RelayExecutor` now owns TCP relay startup orchestration.
- `RelayExecutionPlan` separates relay planning from session runtime mode transition.
- `SessionAdmissionRuntime` owns admission-side callbacks and auth result side effects.
- `SessionLifecycleRuntime` owns lifecycle bookkeeping side effects.
- `ServerSession` shutdown is split into explicit cleanup steps rather than one monolithic `destroy()` body.

This means `ServerSession` is no longer directly responsible for:
- building embedded TLS gate input
- deciding authenticated TCP vs UDP vs fallback execution shape
- directly driving outbound dialing from raw gate result details
- owning admission callback details inline in the handshake path
- mixing lifecycle bookkeeping with socket cleanup in one opaque block

However, `ServerSession` still remains the host for:
- runtime socket lifecycle
- TCP/UDP forwarding loops
- UDP-specific runtime behavior
- final socket/TLS shutdown orchestration

## Recommended Immediate Next Step

The next implementation step after this document should remain modest:

### Recommended next code step
Phase 2B can reasonably stop here and hand off to a later phase.

If further refactoring is desired, the most natural next seams are:
- UDP runtime boundary cleanup
- cross-session shutdown helper evaluation
- eventual `Service` slimming

These are useful, but they are no longer required to claim Phase 2B success.

This keeps Phase 2B incremental and reversible.

It also avoids prematurely over-designing transport abstractions before the core data handoff is clean.

---

## Summary

Phase 2A made the code modular.

Phase 2B should make the architecture **extensible**.

The key design direction is:

- keep the current embedded TLS/TCP path stable
- stop assuming it is the only future edge
- introduce transport-neutral handoff types
- prepare for future QUIC or ECH-capable edge work without forcing it prematurely into the current core
