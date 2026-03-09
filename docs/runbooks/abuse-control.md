# Runbook: Abuse Control

## Purpose

This runbook explains the current abuse-control mechanisms in the Trojan-Pro baseline and how to verify or tune them safely.

## Current Controls

### 1. Per-IP concurrent connection limit

Config:

```json
"abuse_control": {
  "enabled": true,
  "per_ip_max_connections": 64
}
```

Behavior:

- counts active sessions per source IP
- rejects new connections when the limit is reached
- logs:

```text
connection rejected: per-IP concurrent connection limit reached
```

### 2. Authentication failure cooldown

Config:

```json
"abuse_control": {
  "auth_fail_window_seconds": 60,
  "auth_fail_max": 20,
  "cooldown_seconds": 60
}
```

Behavior:

- applies only when the request parses as a valid Trojan request structure
- increments a per-IP auth-failure counter within a time window
- once the threshold is reached, the IP enters cooldown
- new connections from that IP are rejected during cooldown

Expected logs:

```text
authentication failure threshold reached; entering cooldown
connection rejected: IP is in authentication cooldown
```

### 3. Fallback session budget

Config:

```json
"abuse_control": {
  "fallback_max_active": 32
}
```

Behavior:

- authenticated sessions are not counted against this budget
- unauthenticated fallback sessions consume fallback slots
- once the active fallback budget is exhausted, new fallback sessions are rejected

Expected logs:

```text
fallback rejected: active fallback session budget exhausted
```

## Verification

### Run all smoke tests locally

```bash
cmake -S . -B build/scan -DCMAKE_BUILD_TYPE=Release -DENABLE_MYSQL=OFF -DENABLE_SSL_KEYLOG=OFF
cmake --build build/scan -j"$(nproc)"
ctest --test-dir build/scan --output-on-failure -j2
```

### Relevant tests

- `LinuxSmokeTest-auth-fail-cooldown`
- `LinuxSmokeTest-fallback-budget`

## Tuning Guidance

### Conservative defaults

Good starting point:

```json
"abuse_control": {
  "enabled": true,
  "per_ip_max_connections": 64,
  "auth_fail_window_seconds": 60,
  "auth_fail_max": 20,
  "cooldown_seconds": 60,
  "fallback_max_active": 32
}
```

### If you see too many false positives

Possible adjustments:

- increase `per_ip_max_connections`
- increase `auth_fail_max`
- reduce `cooldown_seconds`

### If you are under obvious probing/abuse

Possible adjustments:

- lower `per_ip_max_connections`
- lower `auth_fail_max`
- increase `cooldown_seconds`
- lower `fallback_max_active`

## Troubleshooting

### Problem: legitimate clients are rejected too often

Check:

- whether many users share the same public IP (carrier NAT, company proxy)
- whether the configured thresholds are too aggressive
- whether authenticated clients are accidentally hitting failure paths first

### Problem: fallback budget is exhausted frequently

Check:

- whether decoy traffic is being actively probed
- whether `fallback_max_active` is too small for your deployment
- whether the fallback backend is too slow, causing sessions to linger

### Problem: auth-failure cooldown triggers unexpectedly

Check:

- client-side password mismatch
- stale tokens
- bots replaying malformed Trojan requests
- log lines around `authentication failed` and cooldown events

## Notes

- Current counters are in-process only.
- Current controls are intended as lightweight guardrails, not a full reputation system.
- For multi-instance deployments, thresholds may need redesign if shared state becomes necessary.
