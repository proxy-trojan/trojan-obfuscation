# Runbook: Rollback Verification

## Purpose

Verify that a candidate rollback actually returned the node to baseline behavior.

This runbook complements:
- `docs/trusted-front-rollback-checklist.md`
- `docs/runbooks/profile-selection.md`

It exists because "we disabled the candidate config" is not yet proof that baseline behavior is back.

---

# 1. Preconditions

Before verification starts, record:
- rollback start time
- rollback target config path
- node/profile label expected after rollback
- evidence output path for rollback verification notes

Recommended expectation after rollback:
- profile mode should be `baseline`
- `external_front.enabled = false`

---

# 2. Config Verification

## Check 1 — Active config
Confirm the active config snapshot now shows:

```json
{
  "external_front": {
    "enabled": false
  }
}
```

## Check 2 — Profile mode
Run:

```bash
./scripts/check-profile-mode.sh <active-config.json>
```

Expected result:
- `mode=baseline`
- `valid=true`

If profile mode is ambiguous or still candidate, rollback is incomplete.

---

# 3. Log Verification

After rollback, verify the node no longer shows candidate-only path signals as the active path.

## Signals that should disappear as normal-path indicators
These should no longer be the intended active-path story:
- `incoming trusted-front connection`
- `external-front metadata accepted: trusted`
- `external-front metadata rejected: <reason>`
- `trusted-front ingress rejected: <reason>`

If these are still appearing as part of the intended active configuration, you likely did not really return to baseline.

## Signals that should remain interpretable
Baseline guardrail/fallback signals may still appear when relevant:
- `connection rejected: IP is in authentication cooldown`
- `connection rejected: per-IP concurrent connection limit reached`
- `fallback rejected: active fallback session budget exhausted`

These are not proof of rollback failure by themselves.

---

# 4. Functional Verification

At minimum, confirm:
- baseline path can still start cleanly
- fallback path still behaves normally
- no code revert was required
- operator-visible behavior matches the baseline profile

If a local baseline evidence capture is available, use it as the comparison anchor.

Suggested command:

```bash
./scripts/collect-baseline-validation-evidence.sh <trojan-binary> <output-dir>
```

---

# 5. Runtime Summary Verification

Look for the final runtime summary line:
- `runtime metrics: accepted=...`

Use it to confirm:
- the service returned to a stable run/stop cycle
- rejection/fallback counts are not obviously distorted by rollback residue

This is supporting evidence, not the only evidence.

---

# 6. Minimum Rollback Verdict Template

```markdown
## Rollback Verification
- Active config checked: yes/no
- Profile mode after rollback: baseline / ambiguous / candidate
- Candidate-only signals still active: yes/no
- Baseline evidence re-captured: yes/no
- Fallback behavior normal: yes/no
- Runtime summary captured: yes/no
- Rollback verdict: complete / incomplete / mixed
- Notes:
```

---

# 7. Failure Interpretation

## Complete rollback
- config is baseline
- profile-mode check says baseline
- candidate-only path is no longer the intended story
- baseline behavior is understandable again

## Mixed rollback
- config appears baseline
- but candidate-only signals or operator confusion remain

## Incomplete rollback
- config/profile still imply candidate
- or baseline behavior cannot be confirmed without ad hoc debugging/code changes

---

# 8. Final Rule

Rollback only counts as successful when operators can say:

> This node is back in baseline mode, and we can prove it from config, logs, and a baseline-shaped verification path.

Anything weaker is hope, not rollback.
