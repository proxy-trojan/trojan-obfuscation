# ADR: Client Product Stack and Boundary

## Status

Proposed

## Context

The project is beginning a new product line: a user-facing client that should eventually support multiple platforms.

The existing repository is core/runtime oriented.
A product client adds concerns that do not fit cleanly inside the current backend-style architecture:
- user state
- secret storage
- packaging
- updates
- diagnostics export
- cross-platform UI behavior

A stack choice is needed before scaffolding begins.

## Decision

Use:
- **Flutter** for the client UI shell
- a **local controller boundary** between UI and any future connectivity/runtime integration
- **desktop-first productization** with mobile-ready architecture

## Consequences

### Positive
- one UI stack across desktop and mobile targets
- better long-term cross-platform story than a desktop-only shell
- clearer separation between product UX and engine/runtime logic
- easier staged delivery: shell first, deeper integration later

### Negative
- introduces a new client product stack into a C++-heavy repository
- requires explicit design for controller contracts
- desktop and mobile packaging still need platform-specific release work

## Alternatives Considered

### Tauri + web UI
Good for desktop, weaker story for a single-stack mobile future.

### Qt/QML
Closer to current C++ ecosystem, but heavier product ergonomics and a less attractive mobile/desktop product path for this project.

### Electron
Fast to prototype, but higher runtime overhead and weaker long-term packaging discipline for this use case.

## Final Rationale

The right first move is not to overfit to the current core language.
It is to choose the stack that makes a real multi-platform product maintainable.
Flutter + a local controller boundary gives the cleanest long-term path.
