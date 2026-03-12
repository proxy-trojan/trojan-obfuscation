# ADR-002: Client Product Direction

## Status
Accepted

## Context
The project now includes a user-facing client. The question is whether to continue treating it as a thin wrapper, or to build it as a real product surface.

## Decision
Adopt a desktop-first, mobile-ready client product strategy with a clear controller boundary.

## Decision details
- prioritize Windows / macOS / Linux product usability first
- keep Android in the release pipeline
- do not tightly couple UI code to low-level runtime internals
- invest in profile management, secure storage, runtime lifecycle, logs, and diagnostics before speculative expansion

## Consequences
### Positive
- clearer product focus
- lower long-term maintenance cost
- better multi-platform survivability
- easier testing and staged runtime integration

### Negative
- some advanced protocol/runtime work moves behind usability work
- initial productization work may feel slower than raw feature hacking

## Alternatives considered
- bolt GUI directly onto current core
- pursue desktop and mobile parity simultaneously
- prioritize protocol expansion before client usability

## Rationale
The project is entering product release stage. Usability, diagnostics, and release quality now matter more than experimental breadth.
