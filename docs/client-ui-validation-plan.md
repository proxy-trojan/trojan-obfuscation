# Client UI Validation Plan

## Goal

Move the Trojan-Pro desktop client from an engineering-facing shell toward a UI that is:
- easier to understand
- faster to operate
- more intuitive for first-time users
- still capable for advanced troubleshooting

---

## Phase 1 — Information Architecture Cleanup

### Target
Reduce cognitive load on first launch.

### Actions
- rename `Dashboard` -> `Home` or `Overview`
- move `Packaging` and `Diagnostics` under an `Advanced` navigation group or secondary surface
- simplify labels that feel like internal engineering terms
- keep primary navigation focused on:
  - Home
  - Profiles
  - Settings

### Success signal
A user can identify the main path within 5-10 seconds after launch.

---

## Phase 2 — Task-First Home Page

### Target
Make the main product flow obvious.

### Home page should prioritize
1. current connection state
2. selected profile
3. password readiness
4. runtime readiness
5. primary connect/disconnect CTA
6. one next-step hint

### Demote from first layer
- manifest/update workflow
- packaging export history
- runtime log tails
- full controller event timeline

### Success signal
The user sees what to do next without needing to inspect multiple pages.

---

## Phase 3 — First-Run Guidance

### Target
Prevent the empty-state experience from feeling unfinished.

### Add guided empty states for
- no profile exists
- password not stored
- real adapter not enabled
- runtime health unavailable
- last connection failed

### Success signal
The UI tells the user what to do next instead of expecting them to infer the workflow.

### Current progress
The first callout-style guidance pass has started on Home and Profiles:
- no profile
- missing password
- failed connection
- quick experimental workflow guidance
- a dedicated connect stage card so the primary action is visually dominant

---

## Phase 4 — Advanced Surface Design

### Target
Keep power-user tooling without overwhelming the core flow.

### Advanced area should contain
- Diagnostics
- Packaging / Update workflow
- Runtime health/session/logs
- Event timeline

### Success signal
Advanced tooling remains accessible, but no longer dominates the product shell.

### Additional rule
Settings should also feel like a normal user preferences page, not a list of internal toggles.

---

## Phase 5 — Live Validation

Use `docs/client-ui-ux-checklist.md` during walkthroughs so the review stays user-centered and does not drift back into purely engineering criteria.


### Validation method
Run a real desktop usability walkthrough after Flutter runtime is available.

### Test questions
- Can a new user create/import a profile without confusion?
- Can they find where to set the password?
- Can they identify the main connect button instantly?
- Can they understand why connect failed?
- Can they find troubleshooting/export tools without assistance?

### Success signal
The user completes the core flow with minimal explanation.

### Additional principle for this client
This product should respect an experimental workflow:
- short path to first connection attempt
- obvious next step after failure
- minimal button overload
- important actions visible, dangerous/rare actions demoted
- user-facing labels should sound like product language, not internal implementation language
- users should be able to scan readiness by color/visual emphasis instead of reading every line
- dialogs and subpages should sound like the same product, not separate internal tools

---

## Immediate next implementation pass

If we start UI validation changes now, the highest-value order is:

1. simplify top-level navigation
2. redesign Dashboard into task-first Home
3. add empty-state guidance
4. demote advanced internals
5. polish labels and terminology

## Current progress (2026-03-11 late night)

The first productization pass has started:
- top-level navigation is simplified toward `Home / Profiles / Settings / Advanced`
- the former Dashboard is reshaped into a task-first Home page
- diagnostics/packaging are pushed behind an Advanced surface

This should be treated as the start of the UI validation phase, not as another generic feature phase.
