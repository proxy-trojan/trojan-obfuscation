# Runbook: Iter-3 Truthful Daily Use Triage (I3)

## Goal

Help operators validate and triage **daily-use paths** (quick connect / disconnect / switch) with:

- **truth consistency** across surfaces (Profiles / Dashboard / Advanced)
- **high-frequency action stability** (no misleading success, no action churn)
- **performance regression guardrails** (baseline checks are explicit and reproducible)

> **Hard rule:** do not claim success unless runtime truth is **`runtime-true` + `session-ready`**.

---

## Scope

This runbook applies to desktop internal beta validation and daily-use triage.

Covers:
1. high-frequency actions (connect / disconnect / switch)
2. cross-surface truth consistency symptoms and decision order
3. when to export support bundle vs when to escalate
4. how to use the Iter-3 validation command bundle

Non-goals:
- replacing Iter-1 first-connect onboarding (see `docs/runbooks/first-connect-a1.md`)
- replacing Iter-2 recovery ladder for Top5 failure families (see `docs/runbooks/recovery-ladder-a1.md`)

---

## Preconditions

- Desktop client build installed (internal beta lane).
- You can access **Profiles**, **Dashboard**, **Advanced**.
- You have at least one profile that can run a connect attempt.

Recommended one-command evidence bundle:

```bash
./scripts/validate_iter3_truthful_daily_use.sh
```

The command prints:
- branch / commit
- started_at_utc / finished_at_utc

Use that output as PR evidence.

---

## Daily-use actions and success truth

### Quick Connect
**Success is only when** all of the following are true:
- Runtime posture: **runtime-true**
- Session truth: **session-ready**
- No `stop-pending` / `stale` / `residual` warnings that contradict “connected” claims

If posture is stub/fallback, treat the attempt as **diagnostic only** (not a success).

### Quick Disconnect
**Truthful disconnect** requires exit confirmation:
- UI must not declare disconnected until runtime exit evidence is confirmed.
- If UI is in `stop-pending`, operator should **wait**, not spam retry.

### Switch Profile
**Truthful switch** means:
- selected profile vs active profile distinction remains correct
- Dashboard CTAs operate on the correct active profile
- session truth messaging remains consistent across surfaces

---

## Cross-surface truth mismatch triage (Profiles / Dashboard / Advanced)

### Common symptoms
- One page shows `Live`, another shows `Stale` / `Residual`.
- Dashboard says “Connected” but Profiles shows blocked readiness.
- Advanced shows a last runtime failure that is not reflected elsewhere.

### Triage order (do not reorder)

1. **Stop action churn**
   - Do not spam connect/disconnect/switch.
   - Keep a stable snapshot for evidence.

2. **Check Dashboard session summary**
   - Record current truth label + truth note + recovery guidance.

3. **Cross-check Profiles**
   - Confirm selected vs active profile.
   - Confirm readiness gating state.

4. **Cross-check Advanced**
   - Inspect last runtime failure summary.
   - Verify whether an app/runtime failure is driving stale/residual truth.

5. **If truth remains inconsistent**
   - Export support bundle before attempting recovery actions.
   - Escalate with “truth mismatch” label and evidence pointer.

---

## When to collect evidence / when to escalate

### Collect support evidence when
- truth is `stop-pending` / `stale` / `residual`
- cross-surface truth labels disagree after one refresh
- quick disconnect appears stuck (stop-pending) beyond a reasonable wait

### Escalate when
- truth mismatch reproduces twice under controlled single-action sequences, or
- evidence indicates a state machine invariant break (e.g. active profile does not match action target), or
- performance gate indicates a significant regression (see below)

Include in escalation payload:
- app version / commit / platform
- active vs selected profile state
- truth labels + truth notes (per surface)
- whether support bundle was exported (and artifact pointer)

---

## Performance baseline / regression guardrails

Iter-3 adds a deterministic performance guardrail gate.

- Script: `scripts/perf/compute_daily_action_perf_baseline.py`
- CI gate (synthetic fixtures):

```bash
python3 -m pytest scripts/tests/test_compute_daily_action_perf_baseline.py -q
```

- Optional operator run (local best-effort baseline collection):

```bash
./scripts/perf/compute_daily_action_perf_baseline.py collect \
  --trojan-bin ./build/ci/trojan \
  --output /tmp/daily_action_baseline.json
```

Notes:
- CI uses fixtures to ensure evaluation logic is stable and reproducible.
- Local collection is best-effort and intended for manual baseline evidence.

---

## Cross-runbook alignment

- Iter-1 first connect: `docs/runbooks/first-connect-a1.md`
- Iter-2 recovery ladder (Top5 + evidence-first): `docs/runbooks/recovery-ladder-a1.md`

If guidance conflicts, prefer:
1. evidence-first order for abnormal session truth
2. runtime-true + session-ready as final success truth
