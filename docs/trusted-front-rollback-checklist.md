# Trusted-Front Rollback Checklist

## Status

Draft

## Purpose

Provide a short rollback checklist for trusted-front staging or canary environments.

This checklist assumes the preferred rollback path is:
- disable trusted-front mode
- restore embedded-TLS-only ingress selection
- keep fallback behavior intact

## Use This Checklist When
- trusted-front behavior is suspicious
- rejection reasons are not explainable
- fallback/public-surface realism regresses
- operator confidence is lost
- a staging or canary target behaves differently than expected

---

# 1. Trigger Confirmation

Rollback should start if any of the following occur:
- [ ] trusted-front path behaves differently from design
- [ ] rejection reasons become unclear or unstable
- [ ] passive observation looks worse than baseline
- [ ] active probing reveals more distinctive responses than baseline
- [ ] fallback realism regresses
- [ ] operators cannot explain accepted vs rejected behavior quickly
- [ ] trust-boundary assumptions are no longer credible

If any box is checked, rollback is justified.

---

# 2. Immediate Rollback Action

## Primary action
- [ ] Disable trusted-front mode in config

Example expectation:
```json
{
  "external_front": {
    "enabled": false
  }
}
```

## Intent
The rollback should:
- [ ] stop selecting trusted-front path
- [ ] stop trusting front-provided metadata
- [ ] restore embedded-TLS default path
- [ ] preserve fallback backend behavior

If more than this is needed for recovery, note it as a process failure.

---

# 3. Post-Rollback Verification

After rollback, confirm:
- [ ] embedded TLS default path is selected again
- [ ] trusted-front path is no longer being attempted
- [ ] fallback path still behaves normally
- [ ] public-facing behavior matches the baseline profile
- [ ] operator logs clearly show the node returned to baseline behavior

If any of these are false, rollback is incomplete.

Detailed verification helper:
- `docs/runbooks/rollback-verification.md`

---

# 4. Safety Checks

- [ ] No leftover trusted-front config remains accidentally enabled
- [ ] No node in the target group is still using the staging profile unintentionally
- [ ] No emergency code patch was required to restore baseline behavior
- [ ] Baseline smoke tests are still relevant to the restored state

If rollback requires code revert instead of config restore, treat that as a major staging-process problem.

---

# 5. Incident Notes

Record:
- [ ] what triggered rollback
- [ ] when rollback started
- [ ] when rollback completed
- [ ] whether rollback fully restored baseline behavior
- [ ] what operator signals were missing or misleading

Template:
```markdown
## Rollback Incident Note
- Trigger:
- Start time:
- Completion time:
- Restored baseline confirmed:
- Missing signals:
- Follow-up fixes:
```

---

# 6. After-Action Decision

Choose one:
- [ ] return to staging after fixes
- [ ] hold trusted-front work as a prepared branch
- [ ] stop rollout work and return to baseline-first development

Rollback is not a failure if it works quickly.
Rollback is a failure only if the project cannot return to baseline cleanly.
