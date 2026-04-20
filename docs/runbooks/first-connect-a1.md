# Runbook: A1 First Connect Flow (Iter-1)

## Goal

Provide a reproducible path from install to **first runtime-true connect test**.

> **Success criteria (hard rule):** only when runtime reaches **`runtime-true` + `session-ready`** can the attempt be counted as success.
> Stub/fallback paths are useful for shell diagnostics, but they do **not** count as first-connect success.

---

## Scope

This runbook is for desktop internal beta validation across Linux / Windows / macOS.

Covers:
1. install / launch
2. profile import or create
3. password storage truth
4. readiness gate
5. one-click connect test
6. support bundle export

---

## Preconditions

- Desktop client build is installed (internal beta lane).
- You have one reachable profile target (host/port/SNI known).
- Local device has write access for runtime state and diagnostics export path.

Recommended pre-check command (local evidence bundle):

```bash
./scripts/validate_iter1_first_connect.sh
```

---

## Step 1 — Install and launch

1. Install the latest internal beta artifact for your platform.
2. Launch the desktop client.
3. Confirm app shell starts without crash and Profiles page is reachable.

Record:
- app version / commit
- platform
- launch outcome

---

## Step 2 — Import or create profile

In **Profiles**:

- Use **Import File / Import Text** to load an existing profile, or
- Use **Create** to add a profile manually.

Minimum required fields:
- server host
- server port
- SNI (if required)
- local SOCKS port

---

## Step 3 — Confirm password storage truth

Set Trojan password via **Set Password**.

Check storage truth in profile details:

- `Stored in secure storage` → preferred
- `Stored in temporary fallback (...)` → session-only fallback, still usable for testing but not persistent-safe

Important:
- imported bundles must not silently carry plaintext password into local storage
- local storage state is the only source of truth for “has stored password”

---

## Step 4 — Readiness gate (must pass before connect)

Check readiness panel on selected profile:

- **Blocked**: connect must be blocked, and next action must be shown (e.g. `Open Profiles`, `Open Troubleshooting`)
- **Ready / Ready with warnings**: connect can proceed

If blocked:
1. follow suggested next action
2. fix the failing domain (config/password/runtime/filesystem)
3. re-run readiness until no longer blocked

---

## Step 5 — Run one-click Connect Test from Profiles

Use primary CTA in selected card:

- runtime-true posture: `Connect Test`
- stub posture: `Connect Test (stub path)` (not a success path for this runbook)

Expected behavior:
- connecting state is visible with timeline stages (planned/launching/alive/session-ready)
- failures are classified with failure family + next action

---

## Step 6 — Validate success truth (hard gate)

An attempt is **successful** only if all checks pass:

1. `Runtime Posture` shows **Runtime-true**
2. `Evidence Grade` shows **Evidence-grade**
3. Connect timeline reaches `session-ready`
4. no stop-pending / stale / residual truth warnings for this success snapshot

If any item is missing, classify the attempt as **not successful** and continue remediation.

---

## Step 7 — Disconnect/Exit truthfulness check

When disconnecting/stopping:

- UI must show **waiting for exit confirmation** semantics
- stop-pending state must **not** be presented as fully disconnected/closed

Only after runtime exit evidence is confirmed can session be treated as closed.

---

## Step 8 — Export support evidence

Open Troubleshooting / Diagnostics and export:

1. **Support bundle** (always available for support handoff)
2. **Runtime-proof artifact** (allowed only when posture is Evidence-grade)

If current posture is shell-grade only, treat export as support context, not runtime-proof evidence.

---

## Step 9 — Record matrix evidence

Update `docs/desktop-validation-matrix.md` with:

- platform
- version / commit
- pass/fail/skip result per Iter-1 row
- evidence pointers (CI run URL, local log path, screenshot path)

This step is mandatory for Iter-1 closure.
