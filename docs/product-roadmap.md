# Trojan-Pro Product Roadmap

## Current position

The project has now entered **formal product development**.

What is already in place:
- stable `main` / `develop` workflow
- multi-platform core release pipeline
- multi-platform client packaging pipeline
- formal GitHub release flow
- initial desktop-first client product architecture

What comes next is not more ad-hoc experimentation, but controlled product delivery.

---

## Roadmap Principles

1. `main` stays releasable
2. `develop` absorbs active work
3. every milestone must improve real user value
4. release quality is part of product quality
5. client productization has priority over speculative protocol expansion

---

## Milestone: v1.2.0 — Client MVP Usability

### Goal
Turn the packaged client into a usable MVP for internal and early external testing.

### Scope
- profile CRUD
- profile import/export
- secure secret storage
- runtime launch / stop / status / log
- diagnostics export
- package-level smoke validation

### Exit criteria
- user can install the client
- user can import or create a profile
- user can securely save credentials
- user can launch/stop a session
- user can inspect status/logs
- user can export diagnostics

---

## Milestone: v1.3.0 — Desktop Beta Quality

### Goal
Make the desktop client feel like a real product, not just a packaged engineering shell.

### Scope
- tray/menu behavior
- improved connection lifecycle UX
- stronger error and recovery UX
- update channel skeleton
- better packaging validation and crash handling

### Exit criteria
- desktop install/update path is repeatable
- user-facing errors are understandable
- diagnostics are reliable enough for support
- release candidates can be tested with low ambiguity

---

## Milestone: v1.4.0 — Public Beta Readiness

### Goal
Prepare the project for broader public testing and cleaner external onboarding.

### Scope
- signed / notarized desktop distribution where applicable
- release verification hardening
- install guide / troubleshooting guide
- support workflow and runbooks
- beta onboarding flow

### Exit criteria
- public beta can be distributed with acceptable support burden
- release validation covers install/start/basic usage paths
- docs support first-run users without internal context

---

## Milestone: v1.5.0 — Product Direction Decision

### Goal
Decide the long-term direction of the product line after stable beta evidence exists.

### Decision areas
- desktop-first only vs stronger mobile investment
- client usability priority vs advanced edge/runtime capabilities
- release cadence and support model
- packaging / update channel maturity level

---

## Workstreams

### 1. Core Stability
Keep core multi-platform builds and runtime behavior stable and testable.

### 2. Client Productization
Prioritize user-facing connection lifecycle, settings, logs, and diagnostics.

### 3. Release Engineering
Strengthen CI, artifact validation, release repeatability, and rollback clarity.

### 4. Project Governance
Use milestones, ADRs, issue templates, labels, and release playbooks to keep development orderly.

---

## Success Metrics

### Engineering
- `main` CI pass rate stays high
- release failures trend down
- hotfix frequency remains controlled

### Product
- install success improves
- first-run client usability improves
- diagnostics export is dependable

### Delivery
- every milestone ships with changelog + release notes
- major decisions are recorded as ADRs
- backlog is tied to milestones instead of loose ideas
