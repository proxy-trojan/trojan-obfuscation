# Phase 4 Decision Record

## Status

Proposed

## Decision

The project should pursue a **dual-track but single-mainline** direction:

- **Mainline product direction:** preserve and strengthen the current Trojan-over-TCP/TLS baseline
- **Strategic alignment direction:** move toward first-tier public-edge posture through a trusted external front / edge layer

In short:

> **Keep the backend stable, improve the public edge.**

This means the project should **not** try to reach first-tier camouflage by continuously expanding backend-native transport features first.
Instead, it should keep the current backend strengths and align upward through edge separation, trust-boundary hardening, and deployment shape.

## Context

The project currently has:
- a real Trojan/TCP/TLS baseline
- fallback and plain-HTTP camouflage support
- runtime guardrails and seam-level tests
- a completed Phase 3C preparation slice for external-front handoff
- internal-only trusted-front preparation, but not a real production front source yet

The current gap is no longer only code structure.
The gap is that the project is strong as a practical second-tier baseline, but not yet first-tier in public-edge camouflage.

## Problem

The project risks drifting between two different goals:

1. becoming the strongest deployable Trojan/TCP/TLS baseline
2. becoming a stronger trusted-front / edge-ready platform

If both are treated as equal first priorities inside the same engineering loop, the result is likely to be:
- slower progress on the real deliverable baseline
- architecture work that looks valuable but does not yet improve real-world detectability
- unclear product positioning

## Chosen Direction

### Mainline goal
Preserve and improve the **current deployable baseline**:
- Trojan over TCP/TLS
- fallback behavior
- realistic operator simplicity
- stable rollback
- measurable runtime quality

### Alignment goal
Use a **trusted external front** as the main path toward first-tier camouflage posture.

This implies:
- the backend remains the reliable relay/admission core
- the edge becomes the place where stronger public-facing camouflage can evolve
- future ECH-capable or browser-like public behavior, if pursued, belongs primarily at the edge layer rather than as an immediate backend-native transport rewrite

## Why This Direction

### 1. It preserves current value
The project already has real value as a Trojan/TCP/TLS system.
That value should not be sacrificed for speculative edge experiments.

### 2. It aligns with how first-tier systems actually win
First-tier public-facing camouflage usually comes from:
- realistic front behavior
- stronger public-edge separation
- ECH-capable or browser-like deployment posture
- not just more backend transport code

### 3. It avoids false progress
Continuing to expand internal seams alone would improve architecture without necessarily improving the public-facing posture that actually matters.

### 4. It keeps rollback and deployment discipline intact
A backend-stable / edge-evolving model is easier to stage, observe, and roll back than mixing multiple new protocol families into the core immediately.

## What Must Be Preserved

The following must remain first-class project strengths:
- Trojan/TCP/TLS baseline quality
- fallback realism
- ALPN/SNI control quality
- operator usability
- rollback simplicity
- test and runtime stability

Any future edge work that weakens these without a clear compensating gain should be rejected.

## What “Align With First Tier” Means Here

It does **not** mean:
- immediately adding QUIC ingress
- forcing backend-native ECH
- adding more transport families just to look advanced
- replacing the current core with a research playground

It **does** mean:
- building a credible trusted-front deployment model
- validating a real trust boundary
- improving public-edge camouflage potential
- making detectability claims evidence-based
- staging and rollback planning before rollout

## Practical Phase 4 Direction

### Track A — Preserve and strengthen the current baseline
Allowed work:
- validation support
- observability improvements
- operator documentation
- staging clarity
- targeted baseline hardening

### Track B — Narrow trusted-front advancement
Allowed work:
- staging topology design
- real-source integration criteria
- canary prerequisites
- one narrow real trusted metadata source PoC only after validation gates are ready

## What Should Not Be The Default Next Step

Do not default to:
- more internal-only ingress seam expansion
- QUIC-first experimentation
- backend-native ECH work
- multi-transport feature growth
- abstraction-first transport frameworks

## Decision Rule For Future Code Work

Future protocol-facing work should only be accepted if it satisfies one of these:

### Case A — Baseline value rule
It clearly improves the current Trojan/TCP/TLS deployment value.

### Case B — Edge-alignment rule
It clearly advances the trusted-front / edge path toward a real staged deployment.

If it satisfies neither, it should not be mainline work.

## Success Criteria For This Direction

This direction is working if, after Phase 4:
- the current baseline remains the strongest real deliverable
- the project has a real detectability validation workflow
- the project has a trusted-front staging topology and rollback plan
- there is a clear decision whether to continue real trusted-front source integration
- the project’s public positioning is simpler and more honest

## Short Version

The project should move forward with this rule:

> **Mainline = strong Trojan/TCP/TLS baseline**
> **Alignment = trusted external front for first-tier posture**
> **Do not try to turn the backend itself into every future protocol at once**
