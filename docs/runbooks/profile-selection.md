# Runbook: Profile Selection

## Purpose

Make baseline mode and candidate mode impossible to confuse during Phase 4 work.

This runbook exists because the project should not advance toward first-tier readiness while operators are still guessing:

- which mode a node is in
- which config file is authoritative
- how rollback returns the node to baseline

## Rule

Every node must be in exactly one of these states:

1. **Baseline profile**
2. **Trusted-front candidate profile**
3. **Rolled-back baseline profile**

Anything fuzzier than that is operator debt.

---

# 1. Profile Meanings

## Baseline profile
Reference example:
- `configs/baseline-profile.json-example`

Use when the node should behave as the current mainline deliverable:

- Trojan over TCP/TLS
- fallback preserved
- no trusted-front path enabled
- baseline-safe defaults

### Required config posture
```json
{
  "external_front": {
    "enabled": false
  }
}
```

## Trusted-front candidate profile
Reference example:
- `configs/trusted-front-candidate-profile.json-example`

Use only for explicit staging validation work.

### Required config posture
```json
{
  "external_front": {
    "enabled": true,
    "enable_trusted_front_listener": true,
    "trusted_front_listener_use_mtls": true
  }
}
```

### Important note
This profile is **not** the default project posture.
It is an opt-in staging profile.

## Rolled-back baseline profile
Use after candidate disablement.

### Required property
It must be operationally equivalent to baseline profile for the purposes of:
- ingress path selection
- trust of front-provided metadata
- fallback behavior
- operator understanding

---

# 2. Required Operator Questions

Before starting a node, the operator must be able to answer:

1. Which profile is this node using?
2. Where is the active config snapshot?
3. What exact setting makes this node candidate-enabled or baseline-only?
4. What exact change restores baseline behavior?
5. Where will the evidence artifacts for this run be written?

If any answer is unclear, stop.

---

# 3. Minimum Config Difference To Record

Every candidate run should explicitly record the candidate-relevant diff.

## Baseline
```json
{
  "external_front": {
    "enabled": false
  }
}
```

## Candidate
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

## Why this matters
If the operator cannot point to the exact diff that changed the node’s mode, the rollout is too fuzzy.

---

# 4. Startup Checklist

## Baseline startup
- [ ] active config snapshot saved
- [ ] `external_front.enabled = false`
- [ ] fallback target confirmed
- [ ] output/log path known
- [ ] rollback not needed because node already starts in baseline mode

## Candidate startup
- [ ] active config snapshot saved
- [ ] `external_front.enabled = true`
- [ ] trusted-front listener settings confirmed
- [ ] trust material paths confirmed
- [ ] fallback target confirmed
- [ ] rollback target config already prepared
- [ ] output/log path known

---

# 5. Rollback Mapping

Rollback should map candidate profile back to baseline profile with a config-only change.

## Candidate -> Baseline mapping
```json
{
  "external_front": {
    "enabled": false
  }
}
```

## Rollback confirmation questions
- Is the trusted-front path no longer selected?
- Is front-provided metadata no longer trusted?
- Is fallback still intact?
- Does operator output now match baseline expectations?

If not, rollback is incomplete.

---

# 6. Evidence Expectation

Each run should save:

- active config snapshot
- profile label (`baseline` / `candidate` / `rolled-back-baseline`)
- backend log
- operator notes
- rollback notes if applicable

The profile label should appear in the run notes and evidence bundle name.

---

# 7. Final Rule

Do not let a node be "kind of baseline but also partially candidate".

That is how projects grow mystery behavior, and mystery behavior is just technical debt in a trench coat.
