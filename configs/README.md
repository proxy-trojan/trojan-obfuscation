# Config Profiles

## Purpose

Provide explicit profile examples for Phase 4 work so operators do not have to infer baseline vs candidate posture from ad hoc config fragments.

## Profiles

- `baseline-profile.json-example`
  - mainline deployable posture
  - `external_front.enabled = false`

- `trusted-front-candidate-profile.json-example`
  - staging-only candidate posture
  - trusted-front listener enabled
  - mTLS enabled
  - loopback restriction relaxed intentionally for two-host staging

## Rule

Copy a profile, fill in the real cert/key/password/fallback values, then run:

```bash
./scripts/check-profile-mode.sh <your-config.json>
```

If the mode is not what you expected, do not launch the node.
