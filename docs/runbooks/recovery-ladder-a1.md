# Runbook: A1 Recovery Ladder Triage (Iter-2)

## Goal

Give operators a deterministic **self-recovery-first** path for the Top5 failure families, with a clear escalation boundary and evidence-preservation order.

> **Hard rule:** when session truth is `stop-pending` / `stale` / `residual`, preserve evidence first. Do not jump directly to retry/rollback.

---

## Scope

This runbook is for desktop internal beta triage when a connect flow fails, degrades, or presents inconsistent runtime/session truth.

Covers:
1. failure family classification
2. Top5 ladder (first action / second action / escalation)
3. evidence-first order for stop-pending / stale / residual
4. support handoff payload requirements

---

## Preconditions

- You are using desktop internal beta build.
- You can access **Profiles**, **Dashboard**, and **Troubleshooting/Diagnostics**.
- Validation bundle command is available:

```bash
./scripts/validate_iter2_recovery_ladder.sh
```

---

## Recovery ladder (Top5 failure families)

### 1) `launch` (runtime launch failed)

**Common signal**
- Process fails before stable `alive/session-ready` phase.
- Runtime binary/process startup evidence indicates launch break.

**First action**
1. Open Troubleshooting and inspect runtime launch evidence.
2. Export support bundle once (baseline evidence snapshot).

**Second action**
1. Confirm profile baseline fields (host/port/SNI/local socks) and password storage truth.
2. Retry connect test once after configuration/runtime preconditions are corrected.

**Escalate when**
- repeated launch failure after one corrected retry, or
- launch evidence is missing/inconsistent across pages.

---

### 2) `config` (configuration invalid/incomplete)

**Common signal**
- Readiness blocked by profile/config domain.
- Required fields missing or invalid for selected profile.

**First action**
1. Follow readiness recommendation destination (typically Profiles).
2. Fix required fields and confirm password storage truth.

**Second action**
1. Re-run readiness until blocked state clears.
2. Run one-click connect test from Profiles.

**Escalate when**
- readiness still blocked with same config family after explicit correction.

---

### 3) `environment` (runtime/env dependency unavailable)

**Common signal**
- Readiness/runtime health indicates binary/path/fs/permission dependency missing.

**First action**
1. Open Troubleshooting for environment evidence and actionable hints.
2. Verify runtime dependency availability (binary/path/permissions) and writable diagnostics path.

**Second action**
1. Re-run readiness and ensure destination becomes reachable.
2. Retry connect test once.

**Escalate when**
- environment remains unavailable after dependency/path correction.

---

### 4) `connect` (network/session establishment failed)

**Common signal**
- Launch succeeded but connect/session-ready not reached.
- Failure appears in connect/session establishment stage.

**First action**
1. Keep current failure evidence (timeline + diagnostics summary).
2. Retry connect once from the recommended action entry.

**Second action**
1. If second failure remains same family, export support bundle with both attempts.
2. Mark failure family and runtime posture in triage record.

**Escalate when**
- same connect-family failure reproduces twice with no posture improvement.

---

### 5) `user_input` (operator-driven interruption / invalid operation)

**Common signal**
- Action aborted/cancelled or conflicting operation in progress.
- User-triggered sequence breaks required recovery order.

**First action**
1. Follow recommended next action without parallel conflicting operations.
2. Re-run only one controlled action path (no concurrent connect/disconnect/retry).

**Second action**
1. Confirm action chain in UI timeline is consistent.
2. If still conflicting, export support bundle and capture exact user sequence.

**Escalate when**
- operator sequence is correct but state transitions remain inconsistent.

---

## Evidence-first order (stop-pending / stale / residual)

When any of these truths are present, use this strict order:

1. **Freeze action churn**
   - Do not spam retry/disconnect.
   - Keep the current state snapshot stable.

2. **Open Troubleshooting first**
   - Capture runtime/session truth from troubleshooting surface.

3. **Export support evidence**
   - Export support bundle before retry/rollback.
   - Ensure runtime posture + failure family are included in exported context.

4. **Then perform recovery action**
   - Follow recommendation action after evidence is secured.

5. **Record outcome**
   - success / fail / abandon
   - keep pointer to evidence artifact and timestamp.

---

## Escalation checklist (support handoff)

Include all of the following:

- app version / commit / platform
- runtime posture at failure point
- failure family
- recommendation action and whether destination was reachable
- stop-pending/stale/residual presence
- support bundle artifact pointer
- reproducible step sequence (expected vs actual)

---

## Cross-runbook alignment

- First-connect baseline and success hard gate: see `docs/runbooks/first-connect-a1.md`
- This runbook extends first-connect with Iter-2 recovery triage/evidence-first handling.
- If guidance conflicts, prefer:
  1. evidence-first order for abnormal session truth
  2. runtime-true + session-ready as final success truth
