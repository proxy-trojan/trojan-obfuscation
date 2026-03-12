# ADR-001: Branch and Release Strategy

## Status
Accepted

## Context
The project has moved from experimental development to formal product delivery. It needs a predictable branch and release model.

## Decision
Adopt the following strategy:
- `main` is the stable release branch
- `develop` is the active integration branch
- `feature/*` branches are created from `develop`
- formal releases are cut from `main` via semantic tags
- GitHub release publication is gated by artifact validation

## Consequences
### Positive
- safer release cadence
- clearer rollback point
- less ambiguity around where active work belongs
- cleaner CI expectations

### Negative
- slightly more process overhead
- developers must respect branch discipline

## Alternatives considered
- trunk-only development
- long-lived feature branches
- release directly from ad-hoc stable feature branches

## Rationale
The current project needs a stable delivery line and a separate integration line. This is the simplest model that matches the product stage.
