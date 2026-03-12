# Client UI Validation Review — 2026-03-11

## Review mode

This review is based on the current Flutter UI structure and widget code.
It is a **static UX / information-architecture audit**, not a live runtime usability session.

That means the verdict is already useful, but it still needs a real Flutter run later for confirmation.

---

## Executive verdict

**Conclusion:** the current client UI is already a strong **engineering alpha shell**, but it is **not yet a polished end-user desktop product**.

If judged by the standard of:
- easy to understand on first launch
- quick to complete the primary task
- clear enough for non-developer operators
- avoids making the user read internal runtime jargon

then the answer today is:

## **Not yet fully aligned.**

The product is technically capable, but the UI still feels more like a **developer console** than a **user-first desktop client**.

---

## What already works well

### 1. The product has a clear skeleton
The app is not a mockup anymore.
It already has:
- navigation
- profile flow
- settings flow
- diagnostics/export flow
- packaging/update visibility
- runtime session visibility

That is a solid base for productization.

### 2. The real user task is present
A user can conceptually do the important things:
- create/import profile
- store password
- connect/disconnect
- inspect health/session
- export diagnostics

So the problem is **not missing product capability**.
The problem is **presentation and prioritization**.

### 3. The architecture supports a cleaner UX later
Because the app already separates:
- product state
- controller boundary
- diagnostics
- packaging

we can simplify the UI without tearing apart the implementation.

### 4. The current UI direction is improving
The newest productization pass has started to fix the right problems:
- more explicit first-run guidance
- clearer next-step callouts
- less button overload in the primary profile flow
- a dedicated connect stage card that makes the main action visually dominant
- visual readiness emphasis so users can scan state instead of reading every field
- advanced internals pushed further out of the first user path
- terminology is being simplified so the UI reads more like a product and less like an internal console
- dialog wording and action labels are being aligned across pages so the product feels coherent
- settings and advanced surfaces are being rewritten to feel like user-facing product areas instead of internal control panels

---

## Main UI/UX problems

## P0 — primary task is not visually dominant
A normal user opens a desktop client wanting to answer:

1. Which profile am I using?
2. Is it connected?
3. Where is the main Connect button?
4. If it fails, what should I do next?

Today, that flow is diluted.

The current Dashboard spends too much space on:
- controller telemetry
- runtime session details
- controller timeline
- packaging/update workflow
- internal platform/service assumptions

These are useful, but they are **not the primary first-launch task**.

### Product consequence
The most important path (profile -> password -> connect -> status) is not visually dominant enough.

---

## P0 — too much internal jargon on the main surface
The UI currently exposes many technical/internal terms too early:
- SNI
- Runtime Endpoint
- Controller Telemetry
- Packaging
- Diagnostics Preview JSON
- Export History
- Manifest / Metadata / Rollback

These terms are appropriate for advanced users, but not as first-layer product language.

### Product consequence
The UI looks powerful, but cognitively heavier than it should be.
A first-time user may feel they need to understand the implementation before they can use the app.

---

## P0 — advanced/engineering pages are top-level peers of core usage
Right now the main navigation is:
- Dashboard
- Profiles
- Settings
- Packaging
- Diagnostics

For an internal tool, that is understandable.
For a user-facing desktop client, it is too engineering-heavy.

### Recommended product principle
Top-level navigation should bias toward:
- Home / Connection
- Profiles
- Settings

while:
- Diagnostics
- Packaging
- Runtime internals

should likely live under an **Advanced** area or secondary flow.

---

## P1 — no strong first-run or empty-state guidance
The UI currently has product primitives, but it does not strongly coach the user through the first-run setup.

What a first-run user needs is a guided sequence like:
1. Create or import profile
2. Save Trojan password
3. Check runtime health
4. Connect
5. If connect fails, open diagnostics

Today this path exists, but the UI still expects the user to infer it.

---

## P1 — Dashboard is useful but overloaded
The current Dashboard is information-rich, but it behaves more like an operator panel than a product home page.

It mixes:
- session snapshot
- product layer status
- platform snapshot
- telemetry
- runtime session
- event timeline
- finish-line notes

### Product consequence
The page is informative, but not focused.
A product home page should answer:
- what is my current connection state?
- what should I do next?
- where do I click?

before it explains internals.

---

## P1 — connect/disconnect flow could be more explicit
The Profiles page has the core controls, which is good.
But the experience can be clearer by showing a more explicit connection card:
- selected profile
- password readiness
- runtime readiness
- main connect button
- failure hint

At the moment, the information exists, but is spread between details, snackbars, dashboard, and runtime blocks.

---

## P2 — labels are technically accurate, but not always product-friendly
Examples:
- `Dashboard` could become `Home` or `Overview`
- `Packaging` could become `Updates` or move under `Advanced`
- `Diagnostics` could be `Troubleshooting`
- `Runtime Endpoint` may not belong in the first layer at all

This is not a correctness issue.
It is a **product language** issue.

---

## Product decision summary

### Current identity
The UI is currently best described as:

**engineering-facing desktop control shell**

### Target identity
The UI should become:

**user-first desktop client with advanced operator tooling behind secondary surfaces**

---

## High-confidence recommendations

## Recommendation 1 — redefine the main IA
Proposed primary navigation:
- Home
- Profiles
- Settings
- Advanced

Where `Advanced` contains:
- Diagnostics
- Packaging / Update workflow
- Runtime internals / logs

---

## Recommendation 2 — replace Dashboard with a task-oriented Home page
The home page should prioritize:
1. connection status
2. selected profile
3. password readiness
4. connect/disconnect CTA
5. quick next action

Advanced details should be collapsed or moved below the fold.

---

## Recommendation 3 — add explicit first-run guidance
A first-run/empty-state card should appear when:
- no profile exists
- no password exists
- runtime health is unavailable

This card should tell the user exactly what to do next.

---

## Recommendation 4 — progressive disclosure for advanced data
Keep the deep technical surfaces, but demote them:
- controller telemetry
- runtime session
- stdout/stderr tail
- packaging manifest/export history

These should exist, but not compete with the main task.

---

## Recommendation 5 — define a UI acceptance bar
The UI should pass validation only if a first-time user can do this without explanation:

1. understand what the app is for
2. create/import profile
3. store password
4. connect
5. understand failure state
6. find troubleshooting tools

If that flow still requires “reading the system,” the UI is not finished.

---

## Final product verdict

### Today
- **Architecture:** strong
- **Product skeleton:** strong
- **Operator visibility:** very strong
- **First-time usability:** medium
- **Consumer-like intuitiveness:** not there yet

### Meaning
The app is already a good **internal engineering alpha shell**.
But if the goal is:

> easy, fast, intuitive desktop product

then the UI still needs a **task-first simplification pass**.

---

## Next step for UI validation phase

Do not start with cosmetics.

Start with:
1. information architecture cleanup
2. first-run guidance
3. task-first home/connection surface
4. advanced surface demotion
5. only then visual polish

## Progress note

The first implementation pass has already begun by:
- introducing `Home / Profiles / Settings / Advanced` structure
- turning the former Dashboard into a task-first connection home
- relocating troubleshooting/update-heavy pages into Advanced
- simplifying profile actions to better match short experimental workflows
- adding explicit first-run / next-step guidance instead of expecting the user to infer the flow

The next pass should now focus on first-run guidance quality and user-flow friction removal.
