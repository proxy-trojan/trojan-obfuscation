# Client Product Architecture

## Status

Draft

## Purpose

Start a new product line for a user-facing, multi-platform client experience around the project core.

This document defines the first safe and maintainable architecture boundary for a client product.
It is intentionally focused on:

- product shape
- platform strategy
- local app architecture
- packaging/update/diagnostics concerns

It does **not** treat a user-facing product as "just add a GUI".

---

# 1. Requirements Summary

## Functional goals

The client product should eventually provide:
- profile management
- server/profile import and export
- secure local secret storage
- connection state / health visibility
- diagnostics and log collection
- update channel support
- multi-profile switching
- local validation / staging evidence collection hooks

## Non-functional goals

- desktop support on **Windows / macOS / Linux** in the first serious phase
- mobile support on **iOS / Android** in a later phase without rewriting product logic from scratch
- clear separation between UI shell and connectivity/control logic
- safe rollback of broken releases
- low operational ambiguity for users
- testable packaging and diagnostics flows

## Non-goals for the first phase

- feature-complete mobile parity on day one
- tightly coupling UI code to low-level transport/runtime internals
- bundling every future protocol idea into the first client release

---

# 2. Recommended Product Strategy

## Recommendation

Treat the client as a **new product surface**, not a thin wrapper around the current server-focused codebase.

### Why
The current project core is backend/runtime-centric.
A usable client product needs additional layers that the core does not currently provide:
- user-state model
- secure credential handling
- install/update lifecycle
- platform permissions and background behavior
- import/export UX
- diagnostics packaging
- crash-safe local persistence

If those concerns are not separated early, the client will become fragile fast.

---

# 3. Architecture Recommendation

## Recommended shape

```text
[ User-Facing App Shell ]
        |
        v
[ Client Application Layer ]
  - profile management
  - settings/state
  - diagnostics/log export
  - update workflow
        |
        v
[ Local Controller Boundary ]
  - typed commands/events
  - platform-neutral contract
        |
        +--------------------+
        |                    |
        v                    v
[ Platform Services ]   [ Connectivity Engine Adapter ]
- secure storage        - future-reviewed integration boundary
- tray/menu             - isolated behind local contract
- notifications         - not embedded directly in UI layer
- filesystem
- auto-update hooks
```

## Core principle

**UI shell, application model, platform services, and connectivity engine must remain separate layers.**

That separation is what makes multi-platform support survivable.

---

# 4. Stack Recommendation

## Recommended UI stack

### Flutter
Use **Flutter** for the first product line.

### Why Flutter
- one UI stack for Windows / macOS / Linux / iOS / Android
- strong desktop support is now viable
- good state-management ecosystem
- good packaging story compared with trying to stretch web tooling everywhere
- easier long-term mobile path than a desktop-only stack

## Recommended local boundary

Use a **local controller boundary** between the app shell and any future connectivity/runtime integration.

### Contract shape
- typed request/response commands
- structured event stream for state changes
- versioned local API contract

### Why this matters
This avoids building the app around direct low-level runtime coupling.
It also makes it possible to:
- test the UI without the engine
- swap integration strategy later
- keep diagnostics/export flows deterministic
- move from fake adapter to real adapter without rewriting the app shell
- stage real runtime integration by first rendering launch/config plans, then promoting that seam into config write + process launch/stop, then surfacing session/log visibility for debugging

---

# 5. Phase Plan

## Phase A — Product architecture and shell
Build first:
- design system / navigation skeleton
- profile list/detail model
- settings storage
- secure secret storage abstraction
- diagnostics bundle export
- release/update channel skeleton

### Exit condition
A user can install the app, create/import a profile, store secrets safely, view state, export diagnostics, and exercise a typed local controller boundary — even if transport integration is still stubbed.

## Phase B — Desktop-first usable product
Build next:
- Windows / macOS / Linux packaging
- tray behavior
- profile switching UX
- connection lifecycle UX
- diagnostics collection UX
- stable crash/error reporting

### Exit condition
Desktop builds feel like a real product rather than a developer harness.

## Phase C — Mobile path
Only after desktop UX and local app model stabilize:
- adapt form factor
- background constraints review
- mobile secret storage
- mobile-friendly profile import/share flow

### Exit condition
Mobile becomes a controlled extension of the same product model, not a forked rewrite.

---

# 6. Key Decisions

## Decision 1 — Desktop first, mobile-ready architecture
### Choice
Prioritize desktop product quality first, while selecting a stack that can extend to mobile later.

### Why
Trying to perfect desktop and mobile simultaneously in phase one usually creates two half-products.

## Decision 2 — UI shell must not directly own runtime internals
### Choice
Introduce a local controller boundary.

### Why
This preserves maintainability, testing, and future integration flexibility.

## Decision 3 — Product UX must be treated as first-class engineering work
### Choice
Model import/export, secure storage, updates, logs, and diagnostics explicitly from day one.

### Why
A client product fails in practice much more often on lifecycle/UX/ops than on raw core logic.

---

# 7. Risks and Mitigations

## Risk A — Premature engine coupling
### Impact
UI becomes inseparable from low-level runtime assumptions.

### Mitigation
Define a controller boundary first and keep early shells transport-agnostic.

## Risk B — Multi-platform surface area explosion
### Impact
Too many platform-specific exceptions too early.

### Mitigation
Desktop-first milestone, mobile later, shared app model from day one.

## Risk C — Secret handling inconsistency
### Impact
Unsafe or confusing credential storage across platforms.

### Mitigation
Use platform-native secure storage adapters behind one abstraction.

## Risk D — Productization debt
### Impact
The app technically works but feels like an internal tool.

### Mitigation
Treat packaging, updates, logs, and diagnostics as core scope — not polish.

---

# 8. First Implementation Milestone

## What should be built first

Create a **client shell workspace** with:
- app shell
- profile model
- settings store
- secure storage abstraction
- diagnostics export command
- fake/local stub controller

## What should NOT be built first

Do not start with:
- protocol zoo support
- direct runtime embedding in UI
- platform-specific hacks before shared product model exists

---

# 9. Blunt Recommendation

If the goal is a real user product, the next correct move is:

> **build a multi-platform client shell with a clean controller boundary first**

not:

> "take the current core and bolt a GUI onto it."
