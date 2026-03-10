# Final Capability Comparison (Current Baseline vs Planned Direction)

## Purpose

Provide a realistic comparison of what the project supports **today** versus what the current roadmap is aiming to support **after the planned direction is completed**.

This document intentionally distinguishes:
- **supported now**
- **planned / preparatory only**
- **not yet supported**

It avoids claiming transport or anti-detection properties that the codebase does not yet actually deliver.

---

# 1. Current Baseline: What Is Actually Supported

## Core protocol/runtime roles

### Server mode
- Trojan server over TCP/TLS
- authenticated TCP forwarding
- authenticated UDP associate handling
- fallback forwarding for non-Trojan traffic

### Client / forward roles
- Trojan client mode
- local SOCKS5-facing client behavior
- forward mode
- NAT mode (Linux-dependent feature path)

## TLS and camouflage-related baseline capabilities
- standard TLS-based Trojan traffic shape
- configurable SNI
- configurable ALPN list
- ALPN port override support
- plain HTTP response file support
- fallback-to-backend behavior for non-Trojan traffic

## Security/runtime control features
- per-IP concurrency guardrails
- authentication-failure cooldown
- fallback session budgeting
- optional MySQL-backed authentication/quota path
- smoke/integration tests plus seam-level runtime tests

## What is not actually supported today
- QUIC ingress
- true ECH support in the implemented runtime path
- external-front handoff mode
- WebSocket transport mode
- gRPC transport mode
- HTTP/2 Trojan transport implementation
- standalone `SessionFactory` / `AcceptGate` modules

---

# 2. Planned Direction: What The Current Roadmap Aims To Enable

## Chosen next direction
- external front / ECH-ready edge preparation

## This means
The current roadmap aims to make the backend ready for:
- trusted external edge handoff
- future front-door experimentation
- clearer trust-boundary handling
- future ECH-capable deployments at the edge layer

## This does not mean (yet)
- the backend itself will immediately implement ECH
- the backend will immediately speak QUIC
- transport camouflage will automatically become stronger without additional front implementation

---

# 3. Protocol / Deployment Support Matrix

| Capability | Supported now | After current plan direction | Notes |
|---|---:|---:|---|
| Trojan over TCP/TLS | Yes | Yes | Core baseline capability |
| Authenticated TCP relay | Yes | Yes | Core baseline capability |
| Authenticated UDP associate | Yes | Yes | Already implemented |
| Fallback to preset backend | Yes | Yes | Already implemented |
| Plain HTTP response | Yes | Yes | Useful for simple camouflage |
| ALPN selection / override | Yes | Yes | Already configurable |
| MySQL auth/quota | Optional | Optional | Build/runtime option |
| External trusted front handoff | No | Planned | Phase 3C target direction |
| ECH-ready deployment posture | Partial / preparatory only | Planned | Likely at the front layer, not immediate backend-native ECH |
| QUIC ingress | No | No (not default path) | Explicitly deferred |
| WebSocket transport | No | No | Not on current roadmap |
| gRPC transport | No | No | Not on current roadmap |
| HTTP/2 Trojan transport | No dedicated implementation | No dedicated implementation | ALPN exists, but not a separate Trojan-over-h2 transport mode |

---

# 4. Anti-Detection / Probe-Resistance Comparison

## Important note
No anti-detection system should be described as “undetectable.”
The comparison below is relative and operational, not absolute.

## Current baseline
### Strengths
- Trojan request is hidden behind a real TLS handshake
- non-Trojan traffic can be forwarded to a fallback backend
- plain HTTP requests can receive a configured response
- TLS/SNI/ALPN knobs allow the server to look closer to ordinary HTTPS deployments

### Limits
- public-facing handshake is still the backend's own TLS surface
- no true external front separation yet
- no deployed ECH implementation in the current runtime path
- no QUIC/HTTP/3 camouflage path

## After planned external-front direction
### Expected improvements
- stronger separation between public edge behavior and backend admission logic
- more room for realistic front-door camouflage at the external edge
- cleaner path toward ECH-capable public exposure
- less direct exposure of backend-specific characteristics on the public ingress surface

### Limits that still remain
- strength depends heavily on the actual front implementation and deployment quality
- backend trust mistakes can erase the benefit of a front layer
- without a real ECH-capable edge, “ECH-ready” is only a posture, not a delivered capability

## Relative anti-probing strength (qualitative)

| Deployment shape | Probe resistance | Notes |
|---|---|---|
| Current embedded TLS + fallback | Medium | Already better than obvious proxy signatures, but still exposes the backend's own public TLS behavior |
| Embedded TLS + plain HTTP response only | Medium- | Simple and cheap, but less convincing than a real fallback backend |
| Trusted external front + backend handoff | Medium+ to High | Depends on the realism and trust-hardening of the front deployment |
| True ECH-capable edge deployment | Potentially higher | Not delivered by the current codebase yet |
| QUIC/HTTP/3 ingress path | Unknown / deferred | Not implemented; strength would depend on real protocol behavior and deployment quality |

---

# 5. Performance Comparison

## Current baseline
### Strengths
- C++17 + Boost.Asio runtime
- low-copy / buffer reuse improvements
- multithreaded worker support
- current baseline already tuned around TCP/TLS Trojan behavior

### Costs
- fallback path still incurs backend work
- TLS is terminated at the backend
- service-side UDP orchestration still exists as a local complexity point

## After external-front direction
### Likely trade-off
- public-edge work moves partially out of the backend
- backend may become simpler in public-facing responsibilities
- but an extra hop / front layer may add operational and latency overhead depending on deployment shape

## Relative performance view (qualitative)

| Deployment shape | Throughput/latency expectation | Notes |
|---|---|---|
| Current embedded TLS direct backend | Best raw simplicity | Fewer moving parts, fewer hops |
| Trusted external front + backend | Slightly higher overhead | Better separation, but added front hop / metadata validation path |
| QUIC ingress path | Unknown / deferred | Could help some network conditions, but not implemented and not free operationally |

## Practical conclusion
If pure raw simplicity and lower operational overhead are the priority, the current embedded TLS baseline is still the easiest deployment shape.
The external-front direction is chosen for architecture and probe-resistance potential, not because it is automatically faster.

---

# 6. Security Comparison

## Current baseline security posture
### Positive
- real TLS transport
- explicit authentication path
- abuse-control guardrails
- fallback budget control
- optional quota/accounting via MySQL
- clearer runtime seams and tests than before

### Remaining limits
- public edge and backend are still tightly coupled in the embedded TLS deployment model
- no explicit trusted-front contract yet
- no external metadata validation path yet

## After planned external-front direction
### Expected security improvements
- explicit trust-boundary modeling
- cleaner separation of public ingress vs backend admission
- better foundation for edge-origin validation
- more controlled path for future advanced edge features

### New risks introduced
- trusting front-provided metadata incorrectly
- misconfigured edge/backend trust relationship
- operational complexity of two-layer deployments

## Relative security view (qualitative)

| Deployment shape | Security posture | Notes |
|---|---|---|
| Current embedded TLS baseline | Good | Simpler trust model, smaller deployment surface |
| External front + verified handoff | Potentially better overall | Better separation, but only if trust validation is done correctly |
| External front + weak trust rules | Worse | Easy way to introduce spoofing / metadata-trust bugs |
| Future ECH-ready edge | Potentially best public-facing posture | Still depends on real edge implementation quality |

---

# 7. Final Practical Answer

## If the current roadmap is completed as planned
The project should ultimately support:
- current Trojan-over-TCP/TLS baseline
- authenticated TCP relay
- authenticated UDP associate relay
- fallback backend behavior
- abuse-control and runtime seam coverage
- a cleaner path for trusted external-front deployments
- a more credible path toward ECH-capable public exposure at the edge

## It should not be described as already supporting
- backend-native ECH
- QUIC ingress
- HTTP/3 Trojan transport
- WebSocket or gRPC transport modes

## Short version
- **Current best-supported protocol family:** Trojan over TCP/TLS
- **Current best camouflage posture:** embedded TLS + realistic fallback backend
- **Planned stronger public-facing posture:** trusted external front / ECH-ready edge
- **Not the chosen near-term direction:** QUIC ingress
