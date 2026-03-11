# Capability Evaluation Matrix

## Status

Draft

## Purpose

Provide a small, decision-oriented comparison between the current project and mainstream alternatives.

This document is intentionally:
- qualitative rather than benchmark-heavy
- deployment-aware rather than theory-only
- focused on decision support rather than marketing claims

## Important Notes

1. These ratings are relative and operational, not absolute.
2. Deployment quality can easily move a solution up or down by one level.
3. “Detectability” here means practical probe-resistance / fingerprint exposure risk, not a claim of invisibility.
4. The current project should be evaluated in two forms:
   - **Current baseline:** embedded TLS + fallback
   - **Planned stronger posture:** trusted external front + backend handoff

## Rating Scale

### Detectability / Probe Resistance
- **Medium-** = acceptable but easier to model or fingerprint
- **Medium** = reasonable mainstream baseline
- **Medium+** = stronger than baseline with good deployment discipline
- **High** = top-tier practical camouflage when deployed well

### Deployment Complexity / Operator Burden
- **Low** = small moving-parts count, easy rollback
- **Medium** = manageable but requires careful docs and monitoring
- **High** = more fragile, more operational expertise required

---

# 1. Summary Matrix

| Option | Detectability / Probe Resistance | Deployment Complexity | Operator Burden | Performance / Latency | Rollback Simplicity | Main Strength | Main Weakness |
|---|---|---|---|---|---|---|---|
| **Current project: embedded TLS + fallback** | **Medium** | **Medium** | **Medium** | **Good** | **High** | Balanced, realistic Trojan/TLS baseline | Public TLS surface is still the backend itself |
| **Current project: future trusted external front (planned)** | **Medium+ to High** | **High** | **High** | **Medium** | **Medium** | Best path to stronger public-edge camouflage without QUIC | Not delivered yet; value depends on real front quality |
| **Mainstream Trojan/TLS baseline** | **Medium** | **Low to Medium** | **Medium** | **Good** | **High** | Mature, well-understood deployment shape | Often too similar to “generic TLS proxy” deployments |
| **NaiveProxy-style deployments** | **High** | **Medium to High** | **High** | **Medium** | **Medium** | Browser-like traffic posture is very strong | Operationally heavier and less “simple server” friendly |
| **REALITY-style deployments** | **Medium+ to High** | **Medium** | **Medium** | **Good** | **Medium to High** | Strong public-facing camouflage with relatively lean deployment | Security/detectability quality depends heavily on exact implementation and ecosystem behavior |
| **Hysteria2 / TUIC-style QUIC deployments** | **Unknown to Medium+** | **Medium** | **Medium** | **Potentially very good** | **Medium** | Strong performance potential on difficult networks | QUIC itself can become a policy target; camouflage story is not automatically stronger |

---

# 2. Option-by-Option Notes

## A. Current project — embedded TLS + fallback

### What it is
- Trojan over TCP/TLS
- fallback backend support
- plain HTTP response support
- ALPN / SNI knobs
- explicit runtime guardrails and tests

### Practical position
This is the project’s **current real product posture**.

### Strengths
- good balance of realism and simplicity
- fewer moving parts than front-separated designs
- rollback is simple
- easier to operate than multi-layer edge designs

### Weaknesses
- the backend still exposes its own public TLS surface
- no real front separation yet
- no ECH in the actual runtime path
- no browser-like traffic cover

### Verdict
A credible **second-tier practical baseline**: strong enough to be serious, but not the strongest public-facing camouflage class.

---

## B. Current project — trusted external front + backend handoff (planned)

### What it is
- the project’s chosen future-facing direction
- currently only Stage-1 internal preparation exists
- no real trusted-front deployment yet

### Strengths
- strongest path currently available inside this codebase for improving public-edge posture
- separates edge behavior from backend admission logic
- aligns with future ECH-capable edge thinking

### Weaknesses
- not yet delivered as a real deployment path
- adds operational complexity
- trust-boundary mistakes can erase the benefit quickly

### Verdict
Architecturally promising, but should be treated as **potential strength**, not current delivered strength.

---

## C. Mainstream Trojan/TLS baseline deployments

### Strengths
- mature and easy to reason about
- good compatibility and deployment simplicity
- still a respectable mainstream baseline

### Weaknesses
- many deployments look too similar in practice
- public TLS surface remains directly exposed
- “good enough” can become “easy to profile” if deployment discipline is weak

### Verdict
The current project is broadly in the same family, with some engineering advantages from clearer fallback/runtime control.

---

## D. NaiveProxy-style deployments

### Strengths
- closest to real browser / web traffic posture among common mainstream options
- very strong public-facing camouflage potential
- difficult to compete with using raw TLS-proxy shaping alone

### Weaknesses
- heavier operational/deployment story
- not a drop-in “simple Trojan server” competitor
- higher maintenance burden for some operators

### Verdict
This is closer to the **first-tier camouflage benchmark** than the current project baseline.

---

## E. REALITY-style deployments

### Strengths
- strong public-facing deception value when deployed well
- often better practical camouflage than plain TLS proxying
- can achieve a good complexity-to-benefit ratio

### Weaknesses
- success is very implementation-dependent
- ecosystem behavior matters a lot
- not automatically superior in every network or operational context

### Verdict
A strong benchmark for “lean but harder-to-profile” deployment style.
The current project is not clearly there yet.

---

## F. Hysteria2 / TUIC-style QUIC deployments

### Strengths
- often strong performance on lossy or high-latency networks
- can improve user experience more than TCP/TLS baselines in some scenarios

### Weaknesses
- QUIC is not automatically harder to detect
- in some environments QUIC itself is an obvious policy target
- better transport performance does not equal better camouflage

### Verdict
This is more of a **different strategic route** than a simple “strictly better detectability” route.

---

# 3. Practical Ranking by Dimension

## Detectability / Probe Resistance
1. **NaiveProxy-style deployments**
2. **REALITY-style deployments** / well-deployed trusted external front
3. **Current project embedded TLS + fallback** / mainstream Trojan/TLS baseline
4. **Plain TLS camouflage without realistic fallback discipline**

## Deployment Simplicity
1. **Mainstream Trojan/TLS baseline**
2. **Current project embedded TLS + fallback**
3. **REALITY-style deployments**
4. **Hysteria2 / TUIC-style deployments**
5. **NaiveProxy-style deployments** / trusted external front multi-layer deployments

## Operator Friendliness
1. **Current project embedded TLS + fallback** (if docs/runbooks keep improving)
2. **Mainstream Trojan/TLS baseline**
3. **REALITY-style deployments**
4. **Hysteria2 / TUIC-style deployments**
5. **NaiveProxy-style deployments** / complex trusted-front staging

## Raw Simplicity-to-Value Ratio
1. **Current project embedded TLS + fallback**
2. **Mainstream Trojan/TLS baseline**
3. **REALITY-style deployments**
4. **Hysteria2 / TUIC-style deployments**
5. **NaiveProxy-style deployments**

---

# 4. Current Project Position

## Honest position today
The current project is:
- **not weak** compared with ordinary Trojan/TLS-class deployments
- **not top-tier** compared with the strongest front-separated or browser-like approaches
- **strongest when described as** a well-structured Trojan/TLS baseline with fallback and runtime-control strengths

## Honest position after current Phase 3C work
Phase 3C improves:
- architectural readiness
- future trusted-front integration posture
- observability and trust-boundary preparation

Phase 3C does **not yet** materially upgrade the project into the first camouflage tier by itself.

## Biggest current gap
The biggest gap is not another seam inside the backend.
The biggest gap is the absence of a **real public-edge separation layer**.

---

# 5. Decision Guidance

## If the goal is best simplicity-to-value ratio
Prefer:
- **continue strengthening embedded TLS + fallback baseline**

## If the goal is strongest future camouflage potential inside this codebase
Prefer:
- **narrow real trusted-front source integration**
- but only after staging, rollback, and operator workflows are defined

## If the goal is to compete directly with the strongest public-edge camouflage systems
The project should assume that it needs at least one of:
- real trusted external front separation
- ECH-capable edge support
- browser-like public-edge behavior

Without that, it will likely remain a strong second-tier practical system rather than a first-tier camouflage system.

---

# 6. Final Verdict

## Current best description of the project
- **Strong second-tier practical baseline**
- **Good engineering structure**
- **Not yet first-tier public-edge camouflage**

## Short version
- against ordinary Trojan/TLS-class systems: **competitive**
- against first-tier front-separated/browser-like systems: **still behind**
- against QUIC-first systems: **different route, not directly better or worse in all conditions**
