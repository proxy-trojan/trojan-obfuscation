# Phase 3C Handoff Contract Draft

## Status

Draft

## Goal

Define a trusted handoff contract between a future **external front / edge layer** and the current Trojan-Pro backend so that future front-door experiments can reuse the existing admission, relay, and runtime seams without reopening a monolithic session path.

## Scope

This draft does **not** implement a new transport.

It defines:
- what an external front may provide to the backend
- what the backend must validate
- what remains owned by the backend
- how embedded TLS and future external-front modes may coexist

## Non-goals

- no QUIC implementation
- no ECH implementation
- no transport-adapter hierarchy rollout
- no implicit trust of front-provided metadata
- no removal of the current embedded TLS ingress path

---

# 1. Deployment Model

## Current baseline

Today, the backend owns:
- TCP/TLS listener
- TLS handshake
- Trojan request parsing
- admission decisions
- relay execution
- runtime forwarding

## Future external-front model

A future deployment may place a trusted front layer in front of the backend.

Possible examples:
- a TLS terminator under our control
- a front proxy with stronger public-facing camouflage
- an ECH-capable edge in front of the current backend

In that model:
- the **front** owns public ingress behavior
- the **backend** continues to own Trojan admission, relay planning, and runtime forwarding

---

# 2. Handoff Contract Principles

## Principle 1 — backend remains authoritative for admission
The backend must remain the final authority for:
- Trojan request validity
- authentication result
- fallback vs authenticated path selection
- relay execution decision

Front-provided metadata may assist the backend, but must not replace admission logic.

## Principle 2 — front metadata is optional, not assumed
The backend must be able to operate in at least two modes:
- embedded TLS mode (current baseline)
- trusted external-front mode

Missing front metadata must never crash or silently corrupt backend behavior.

## Principle 3 — trust must be explicit
The backend must not trust arbitrary upstream headers or side-channel metadata.

Trusted-front mode requires explicit deployment trust rules.

## Principle 4 — downstream input shape should stay familiar
The external-front path should produce a backend-facing input shape that aligns with the current architecture style:
- session context
- ingress metadata
- initial payload / transport hints

The goal is reuse, not parallel architecture.

---

# 3. Proposed Backend-Facing Metadata

A future external front may provide a structure conceptually similar to:

```cpp
struct ExternalFrontContext {
    std::string trusted_front_id;
    std::string original_client_ip;
    uint16_t original_client_port{0};
    std::string server_name;
    std::string negotiated_alpn;
    std::string ingress_mode;
    bool tls_terminated_by_front{false};
    bool metadata_verified{false};
};
```

## Notes

### `trusted_front_id`
Identifies which approved front produced the handoff.

### `original_client_ip` / `original_client_port`
Optional client-origin metadata.
Must not be trusted unless the backend has verified the front.

### `server_name`
Optional SNI-like context if known to the front.

### `negotiated_alpn`
Optional ALPN context if negotiated at the front.

### `ingress_mode`
Helps distinguish paths such as:
- embedded_tls
- external_front
- future_quic

### `tls_terminated_by_front`
Explicitly indicates whether the public TLS session ended at the front.

### `metadata_verified`
Must be set only after backend-side trust validation succeeds.

---

# 4. Ownership Boundaries

## Front owns
- public-facing camouflage
- public TLS surface behavior
- future ECH exposure if implemented there
- any front-only protocol-specific negotiation

## Backend owns
- Trojan request parsing
- authentication
- fallback vs authenticated path choice
- abuse-control logic
- relay planning
- runtime forwarding
- usage accounting

This boundary keeps the backend useful even when ingress shape changes.

---

# 5. Trust Model

## Required rule
The backend must only accept front-provided metadata from an explicitly trusted front channel.

## Minimum validation requirements
At least one of the following must exist before trusting metadata:
- mutually authenticated backend-facing TLS
- loopback / unix-socket trust boundary
- static allowlisted upstream identity plus transport isolation
- signed metadata envelope verified by the backend

## Must not do
The backend must **not** blindly trust:
- raw HTTP headers like `X-Forwarded-For`
- ad-hoc metadata from arbitrary peers
- plaintext upstream claims without an authenticated trust boundary

---

# 6. Coexistence Model

The backend should support both:
- current embedded TLS ingress
- future trusted external-front ingress

This means any future implementation should be additive, not a replacement rewrite.

A likely approach is to introduce a concrete boundary such as:
- `ExternalFrontContextBuilder`
- or `ExternalFrontInbound`

That boundary should feed the same downstream style of logic already used by the backend session path.

---

# 7. Failure Handling Rules

## If metadata validation fails
The backend must fail closed for trusted-front-only fields.

Reasonable outcomes:
- reject session
- drop to conservative handling with no trusted metadata
- record warning / metric for invalid front handoff

## If optional metadata is absent
The backend should still function, using embedded-TLS-compatible assumptions where possible.

## If metadata is inconsistent
Examples:
- front claims ALPN that conflicts with payload expectations
- front claims a client IP in an impossible form

The backend should:
- reject or ignore the inconsistent metadata
- avoid silently mixing trusted and untrusted fields

---

# 8. Testing Strategy

Phase 3C should begin with contract-level tests, not end-to-end transport implementation.

## First test targets
- accepted trusted-front metadata shape
- invalid metadata rejection
- missing metadata fallback behavior
- trust-boundary validation outcomes

## Explicitly later
- full front implementation
- real ECH behavior
- real QUIC behavior

---

# 9. Recommended Next Implementation Step

Introduce a concrete draft boundary in documentation and design first, then implement one narrow code seam.

Recommended next code seam:
- a backend-facing external-front context builder / validator

Not recommended yet:
- a general `IInboundAdapter` hierarchy
- a QUIC ingress implementation
- a broad transport-abstraction layer

---

# 10. Success Criteria

This handoff-contract phase is successful when:
- trusted-front responsibilities are clearly separated from backend responsibilities
- backend trust requirements are explicit
- future external-front work can begin without reopening Phase 2/3A/3B refactors
- the project still preserves the current embedded TLS baseline as a valid deployment mode
