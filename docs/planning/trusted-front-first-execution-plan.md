# Trusted-Front First Execution Plan

## Status

Proposed

## Purpose

Define the first concrete execution path for the trusted-front direction.

This plan is intentionally narrow.
It does not attempt to deliver production trusted-front support in one step.
It defines:
- the first real-source shape
- the first code slice worth implementing
- how the first candidate validation report should be produced

## Requirements Summary

### Functional
- preserve the current Trojan/TCP/TLS baseline
- keep rollback simple
- introduce a real trusted-front metadata source shape that is more credible than config-only stubs
- make the first candidate comparable against the baseline using the Phase 4 workflow

### Non-functional
- default-off
- staging-only
- explicit trust boundary
- operator-visible failures
- minimal blast radius

## Chosen First PoC Shape

### Decision
Use a **two-host staging design with an mTLS-protected internal hop** and a **trusted-front envelope** as the first real-source shape.

### Envelope format
For the first PoC, the envelope should be:
- **length-prefixed JSON envelope over the trusted internal hop**
- carrying the same semantic fields already modeled by `TrustedInternalHandoffInput`

This is a PoC choice, not a final protocol commitment.

### Why this choice
It is the smallest shape that is:
- more real than config stub injection
- easier to debug than a more opaque binary framing first
- compatible with the current input contract / builder / handoff chain
- narrow enough not to turn Phase 4 back into transport sprawl

## Alternatives Considered

### A. Keep config stub and claim staging readiness
Rejected:
- too weak
- no real trust-boundary exercise
- no meaningful public-edge proof

### B. Jump directly to PROXY protocol TLV or custom binary framing
Deferred:
- potentially useful later
- too much complexity for the first serious execution slice

### C. Add a side-channel control plane first
Deferred:
- stronger long-term possibility
- too much moving-part complexity for the first PoC

## First Development Slice

### Slice 1 — Trusted-front envelope definition and parser
Goal:
- define and validate the first real-source payload shape

Deliverables:
- `trusted_front_envelope` parser/validator
- mapping into `TrustedInternalHandoffInput`
- seam-level tests for invalid JSON / invalid envelope / valid envelope

### Slice 2 — Dedicated internal trusted-front ingress
Goal:
- receive envelope + forwarded traffic across a trusted internal boundary

Deliverables:
- internal-only listener mode
- explicit trust-boundary guard (mTLS)
- connection path into existing handoff flow

### Slice 3 — First candidate evidence run
Goal:
- compare trusted-front candidate against baseline using the same workflow

Deliverables:
- candidate evidence bundle
- candidate validation report
- before/after judgment against baseline

## Execution Steps

### Step 1
Land envelope parser and tests.

### Step 2
Land internal-only trusted-front ingress guarded by mTLS.

### Step 3
Stand up the two-host staging topology.

### Step 4
Collect candidate evidence using the same categories as the baseline:
- passive observation
- active probing
- public-surface realism
- operator visibility
- rollback behavior

### Step 5
Write the candidate validation report and compare it against baseline.

## Success Criteria

The first trusted-front candidate only counts as a success if:
- public-edge posture is meaningfully better than baseline
- active probing is not more distinctive
- operator visibility is still sufficient
- rollback still works with config-level disablement

## Failure Criteria

The candidate should be considered a failure or pause point if:
- the public edge still effectively looks like direct backend TLS
- complexity rises without a clear evidence-based gain
- trust assumptions are not explainable
- operator diagnosis becomes worse
- rollback becomes fragile

## Final Recommendation

Start with:
1. **trusted-front envelope parser + tests**
2. then **internal-only mTLS-backed ingress**
3. then **candidate evidence collection**

This is the smallest path that can genuinely answer whether trusted-front work deserves more mainline investment.
