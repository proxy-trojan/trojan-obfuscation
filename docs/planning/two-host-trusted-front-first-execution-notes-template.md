# Two-Host Trusted-Front First Execution Notes Template

## Status

Template

## Purpose

Record the first real two-host trusted-front staging attempt in a way that supports later comparison against the baseline.

Use this template during or immediately after execution.

---

# 1. Run Identity

- **Date:**
- **Reviewer:**
- **Operator owner:**
- **Rollback owner:**
- **Scope:**
- **Goal of this run:**

---

# 2. Topology Snapshot

## Host A — trusted front
- Hostname/IP:
- Front process / transport details:
- Client certificate path:

## Host B — backend
- Hostname/IP:
- Backend build / commit:
- Trusted-front listener port:
- Fallback backend details:

## Trust boundary
- Internal mTLS details:
- CA source:
- Any allowlist or firewall assumptions:

---

# 3. Candidate Config Snapshot

Record only the candidate-relevant settings.

```json
{
  "external_front": {
    "enabled": true,
    "enable_trusted_front_listener": true,
    "trusted_front_listener_use_mtls": true,
    "require_trusted_front_loopback_source": false,
    "trusted_front_listener_addr": "...",
    "trusted_front_listener_port": ...
  }
}
```

## Notes
- Were any non-default settings required?
- Did anything feel fragile or surprising?

---

# 4. Passive Observation Notes

## What was observed from the public-facing side
- TLS/certificate posture:
- ALPN behavior:
- Public response coherence:
- Anything obviously backend-like:

## Compared with baseline
- Better / same / worse:
- Why:

---

# 5. Active Probing Notes

## Probe categories run
- [ ] non-protocol connection
- [ ] malformed request
- [ ] HTTP-like request
- [ ] candidate trusted-front transport send
- [ ] fallback-triggering case

## Results
- Distinctive failures:
- Stable rejection reasons:
- Any surprising behavior:

## Compared with baseline
- Better / same / worse:
- Why:

---

# 6. Candidate Path Observability Notes

## Backend-side observations
- Trusted-front path accepted?
- Trusted-front path rejected?
- Rejection reason(s):
- Fallback path seen?
- Tunnel established?

## Front-side observations
- mTLS connection success?
- Envelope/frame send success?
- Downstream response captured?

## Missing signals
- What could not be seen clearly?

---

# 7. Rollback Notes

- Rollback triggered? yes/no
- If yes, why?
- How long did rollback take?
- Did baseline behavior return cleanly?
- Any rollback surprises?

---

# 8. Verdict

## Candidate result
- [ ] Improved
- [ ] No meaningful change
- [ ] Mixed / uncertain
- [ ] Worse

## Short explanation

Write one blunt sentence:

> The candidate is / is not yet worth its added complexity because ...

---

# 9. Tier Judgment

## Did this run move the project into the first tier?
- [ ] Yes
- [ ] No

## Why
Be strict here.
A “yes” requires evidence that the candidate has materially improved the public-edge posture, not just internal runtime structure.

---

# 10. Next Action

Choose one:
- [ ] run another two-host staging iteration
- [ ] fix a specific candidate weakness
- [ ] return to baseline-first work
- [ ] pause trusted-front work

## Follow-up notes
- Highest-value next change:
- Biggest current blocker:
- Biggest remaining uncertainty:
