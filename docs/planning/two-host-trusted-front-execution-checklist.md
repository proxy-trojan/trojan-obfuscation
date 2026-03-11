# Two-Host Trusted-Front Execution Checklist

## Status

Prepared

## Purpose

Provide a concrete checklist for the **first real two-host trusted-front staging execution**.

This checklist is intentionally practical.
It assumes the project already has:
- local candidate evidence
- trusted-front runtime path
- mTLS-capable internal listener shape
- two-host staging bundle preparation support

It does **not** assume production rollout.

---

# 1. Scope Confirmation

- [ ] This run is **staging only**
- [ ] This run uses **exactly two hosts**
- [ ] This run is intended to produce **candidate evidence**, not a production claim
- [ ] This run has a named reviewer / operator owner
- [ ] This run has a planned rollback owner

## Execution note
If the run is not clearly staging-only, stop.

---

# 2. Host Role Confirmation

## Host A — trusted front
- [ ] Public-facing role is clear
- [ ] Front-side transport plan is clear
- [ ] Client certificate for internal mTLS hop is ready
- [ ] Front-side logging plan exists

## Host B — backend
- [ ] Backend candidate config exists
- [ ] Trusted-front listener cert/key exist
- [ ] CA trust chain exists
- [ ] Fallback backend path exists
- [ ] Baseline rollback config is available

If either host role is fuzzy, stop.

---

# 3. Trust Material Check

- [ ] Shared staging CA exists
- [ ] Backend trusted-front listener cert exists
- [ ] Backend trusted-front listener key exists
- [ ] Front client cert exists
- [ ] Front client key exists
- [ ] Backend trusted-front CA file is configured

## Recommended source
Use the generated two-host staging bundle as the base input.

If trust material is incomplete or ad hoc, stop.

---

# 4. Backend Candidate Config Check

- [ ] `external_front.enabled = true`
- [ ] `enable_trusted_front_listener = true`
- [ ] `trusted_front_listener_use_mtls = true`
- [ ] `trusted_front_listener_addr` is correct for Host B
- [ ] `trusted_front_listener_port` is correct for Host B
- [ ] `trusted_front_tls_cert` points to the correct backend listener cert
- [ ] `trusted_front_tls_key` points to the correct backend listener key
- [ ] `trusted_front_tls_ca` points to the staging CA
- [ ] `require_trusted_front_loopback_source` is deliberately configured for two-host use

## Important note
For a real two-host run, leaving `require_trusted_front_loopback_source = true` will usually break the candidate path.
That change must be intentional and documented.

---

# 5. Front Transport Check

- [ ] The front can open an mTLS connection to the backend trusted-front listener
- [ ] The front can send a trusted-front envelope
- [ ] The front can append downstream payload after the envelope frame
- [ ] The front can capture basic client-side evidence

If the front cannot actually deliver envelope + downstream payload, stop.

---

# 6. Observability Check

## On the backend
- [ ] Trusted-front acceptance is visible
- [ ] Trusted-front rejection is visible
- [ ] Rejection reasons are visible
- [ ] Fallback path activity is visible
- [ ] Baseline path activity is still understandable

## On the front
- [ ] Connection attempts can be logged
- [ ] mTLS handshake failures can be observed
- [ ] Transport send/receive failures can be observed

If operators cannot explain the flow from logs, stop.

---

# 7. Validation Workflow Check

- [ ] Passive observation plan exists
- [ ] Active probing plan exists
- [ ] Public-surface realism checks are planned
- [ ] Before/after comparison target is clear
- [ ] Baseline report is available as the reference

## Required question
What exact candidate-vs-baseline claim are we trying to validate?

If the answer is vague, stop.

---

# 8. Rollback Check

- [ ] Baseline rollback path is documented
- [ ] Trusted-front mode can be disabled cleanly
- [ ] Operators know which config change restores baseline behavior
- [ ] Rollback verification steps are ready
- [ ] Rollback does not require code revert

If rollback is not clearly easier than recovery-by-debugging, stop.

---

# 9. Evidence Bundle Check

Before starting, confirm where evidence will go.

- [ ] Front-side evidence location defined
- [ ] Backend-side evidence location defined
- [ ] Candidate evidence report target location defined
- [ ] Baseline comparison target identified

## Suggested outputs
- front transport logs
- backend server log
- backend candidate config snapshot
- passive observation transcript(s)
- candidate execution notes

---

# 10. Final Go / No-Go

## Go only if all answers are yes
- [ ] Trust boundary is clear
- [ ] mTLS material is ready
- [ ] Backend candidate config is ready
- [ ] Front can actually send the ingress frame
- [ ] Observability is good enough
- [ ] Rollback is ready
- [ ] Evidence capture locations are known

## Final decision
- [ ] **Go**
- [ ] **No-Go**

## Sign-off
```markdown
- Date:
- Reviewer:
- Operator owner:
- Rollback owner:
- Scope:
- Known risks:
```
