# Trusted-Front Rollout Checklist

## Status

Draft

## Purpose

Provide a short, operator-facing checklist for deciding whether a trusted-front staging or canary rollout is allowed to begin.

This checklist is intentionally conservative.
If an item is unclear or unverified, the rollout should pause.

## Usage

Use this checklist before:
- enabling trusted-front mode in staging
- promoting a staging deployment toward canary
- re-enabling trusted-front mode after a rollback

---

# 1. Direction Check

- [ ] This rollout aligns with the current mainline rule: **keep the backend stable, improve the public edge**
- [ ] This rollout is not trying to sneak in a new transport family
- [ ] This rollout has a clear validation goal (not “just try it and see”)
- [ ] The target deployment shape is documented

## Required answer
**What exactly are we trying to prove with this rollout?**

Examples:
- verify trusted-front acceptance/rejection logic in staging
- validate trust boundary correctness over an mTLS-protected internal hop
- compare detectability signals before and after front separation

If there is no clear answer, stop.

---

# 2. Topology Check

- [ ] The topology is explicitly documented
- [ ] Public edge / trusted front role is identified
- [ ] Backend role is identified
- [ ] Fallback backend role is identified
- [ ] Operators know which nodes are baseline-only and which nodes are trusted-front staging nodes

## Recommended minimum serious shape
- [ ] two-host staging
- [ ] trusted front on one host
- [ ] backend on another host
- [ ] internal trusted boundary documented

If this is only a same-host PoC, mark it clearly as such and do not treat it as canary evidence.

---

# 3. Trust Boundary Check

- [ ] The trusted metadata source is explicit
- [ ] The backend can explain why that metadata is trusted
- [ ] The boundary is one of the accepted staging forms:
  - [ ] mTLS-protected internal hop
  - [ ] loopback / same-host PoC only
  - [ ] tightly allowlisted internal segment with explicit control assumptions
- [ ] The rollout does **not** rely on “we think this network path is probably safe” reasoning

## Hard stop conditions
Stop if any of the following are true:
- [ ] metadata provenance is informal
- [ ] the front can inject metadata without an explicit trust story
- [ ] operators cannot explain why spoofing should be prevented

---

# 4. Baseline Preservation Check

- [ ] Embedded TLS remains the default ingress for non-target nodes
- [ ] `external_front.enabled` is still opt-in only
- [ ] Baseline configuration remains available and ready
- [ ] Baseline deployment can be restored without code rollback
- [ ] The rollout does not weaken fallback behavior or baseline operator usability

If trusted-front mode cannot be turned off cleanly, stop.

---

# 5. Validation Workflow Check

- [ ] A detectability validation run plan exists
- [ ] Passive observation will be captured
- [ ] Active probing will be captured
- [ ] Fallback / public-surface realism will be captured
- [ ] Before/after comparison criteria are defined
- [ ] Success is not being judged only by “the code path works”

## Required question
**How will we know this rollout improved, preserved, or worsened the public-facing posture?**

If there is no answer, stop.

---

# 6. Observability Check

- [ ] Operators can see when embedded TLS default path is selected
- [ ] Operators can see when trusted-front path is attempted
- [ ] Operators can see when trusted-front path is accepted
- [ ] Operators can see when trusted-front path is rejected
- [ ] Rejection reasons are stable enough to be actionable
- [ ] Operators can distinguish fallback behavior from trusted-front behavior

## Minimum reason visibility
Examples of acceptable stable reasons include:
- `missing_trusted_front_id`
- `missing_original_client_identity`
- `missing_verified_tls_termination`
- builder/source rejection reasons

If operators cannot explain what happened from the logs, stop.

---

# 7. Rollback Readiness Check

- [ ] Rollback method is documented
- [ ] Rollback can be performed with a config change only
- [ ] Rollback owner is assigned
- [ ] Rollback verification steps are written down
- [ ] Operators know how to confirm return to embedded-TLS-only mode

## Minimum rollback expectation
- [ ] disable external-front path
- [ ] stop trusting front metadata
- [ ] preserve baseline ingress
- [ ] preserve fallback behavior

If rollback requires ad hoc debugging under pressure, stop.

---

# 8. Test / Quality Gate Check

- [ ] Baseline smoke tests are green
- [ ] Runtime seam tests are green
- [ ] No new config drift is unaccounted for
- [ ] The rollout target uses the intended config profile
- [ ] Operator-facing docs are current enough for the target shape

If test results are stale or partial, stop.

---

# 9. Rollout Scope Check

- [ ] This rollout starts with staging only
- [ ] Scope is narrow and explicitly limited
- [ ] No full-fleet enablement is planned as a first step
- [ ] Canary expansion conditions are predefined
- [ ] Abort conditions are predefined

## Good rollout scope examples
- one staging environment
- one backend behind one trusted front
- limited traffic class or test-only traffic

## Bad rollout scope examples
- “enable everywhere and watch logs”
- “turn on for all nodes because code exists now”
- “mix trusted-front rollout with QUIC experiments”

---

# 10. Approval Summary

## Rollout is allowed only if all answers below are “yes”
- [ ] We know what this rollout is proving
- [ ] We know where the trust boundary is
- [ ] We know how operators will observe it
- [ ] We know how to compare before vs after
- [ ] We know how to roll back immediately
- [ ] We know how to confirm rollback success

## Final decision
- [ ] **Approved for staging**
- [ ] **Approved for narrow canary**
- [ ] **Not approved — fix gaps first**

## Notes
```markdown
- Reviewer:
- Date:
- Scope:
- Open risks:
- Conditions before next stage:
```
