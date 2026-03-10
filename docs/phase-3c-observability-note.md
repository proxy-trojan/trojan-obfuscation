# Phase 3C Observability Note

## Status

Draft

## Purpose

Record the minimal operator-facing observability posture for the current external-front integration stage.

At the current stage:
- embedded TLS remains the default path
- external-front mode remains config-gated and default-off
- runtime observability should explain why an external-front attempt was accepted or rejected
- no broad metrics rollout is required yet

## Current minimal runtime signals

When a `ServerSession` has an injected external-front context, the ingress-selection step should produce a clear log outcome:
- `external-front metadata accepted: trusted`
- `external-front metadata rejected: <reason>`

Where `<reason>` comes from the stable validation status string, for example:
- `missing_trusted_front_id`
- `missing_original_client_identity`
- `missing_verified_tls_termination`

## Why logs first, not metrics first

At this stage the project has:
- trust policy
- validation results
- ingress selection seam
- config gate

But it does not yet have:
- a real production metadata source integration
- mature operator expectations for external-front rollout

Logs are enough to support the next narrow integration step.
Metrics can be added later when the live path becomes more real.

## Current recommendation

Keep observability narrow and operator-readable:
- no silent trust failures
- no broad metrics expansion yet
- preserve embedded-TLS baseline without additional default-path noise
