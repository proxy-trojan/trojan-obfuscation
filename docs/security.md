# Security Hardening Status

## Scope

This document captures the current security hardening status of the `feature_1.0_no_obfus_and_no_rules` baseline.
It focuses on implemented protections, known gaps, and operational caveats.

## Current Baseline

The current baseline includes:

- Sensitive authentication log redaction
- Real smoke/integration tests
- CI smoke workflow on Linux
- SSL keylog build/runtime guardrails
- MySQL remote-TLS warning guardrail
- Per-IP concurrent connection limits
- Authentication failure cooldown
- Dedicated fallback session budget
- Runtime abuse-control metrics

## Implemented Protections

### 1. Authentication log redaction

Server-side logs no longer print:

- raw configured passwords
- authentication token prefixes
- full Trojan password/token values on auth failure

Current logs use generic messages such as:

- `authenticated by configured credential`
- `authenticated by external authenticator`
- `valid trojan request structure but authentication failed`

### 2. SSL keylog guardrail

`ENABLE_SSL_KEYLOG` is disabled by default.

Implications:

- release builds do not expose TLS session secrets by default
- `--keylog` now fails fast unless explicitly compiled with `-DENABLE_SSL_KEYLOG=ON`
- when enabled, it is treated as a debugging-only capability

### 3. MySQL transport warning

If MySQL authentication is enabled against a non-local server and `mysql.ca` is not configured, the server logs a warning indicating that transport security is not guaranteed.

### 4. Abuse-control protections

#### Per-IP concurrent connections

Config:

```json
"abuse_control": {
  "enabled": true,
  "per_ip_max_connections": 64
}
```

If a source IP exceeds the configured concurrent connection limit, new connections are rejected before entering the session flow.

#### Authentication failure cooldown

Config:

```json
"abuse_control": {
  "auth_fail_window_seconds": 60,
  "auth_fail_max": 20,
  "cooldown_seconds": 60
}
```

Applies only to:

- requests that parse as a valid Trojan request
- but fail authentication

Does **not** apply to ordinary fallback traffic.

#### Fallback budget

Config:

```json
"abuse_control": {
  "fallback_max_active": 32
}
```

Unauthenticated fallback traffic has its own active-session budget.
When the fallback budget is exhausted, new fallback sessions are rejected.

## Runtime Metrics

The service currently records and prints summary metrics on shutdown:

- `accepted_connections_total`
- `rejected_connections_total`
- `rejected_fallback_total`
- `auth_success_total`
- `auth_failure_total`
- `fallback_connections_total`
- `active_sessions`
- `active_fallback_sessions`

These are currently in-process counters intended for local observability and test validation.

## Validation Coverage

Current smoke/integration tests:

- `LinuxSmokeTest-basic`
- `LinuxSmokeTest-server-config-fails`
- `LinuxSmokeTest-auth-fail-cooldown`
- `LinuxSmokeTest-fallback-budget`

These tests are also wired into `.github/workflows/ci-smoke.yml`.

## Known Gaps

The following are **not** fully addressed yet:

1. No external metrics exporter (Prometheus, OpenTelemetry, etc.)
2. No per-IP reputation or distributed/shared state across instances
3. No dedicated fallback connect-timeout budget yet
4. No decoy/backend health-aware admission control
5. No advanced anomaly scoring or adaptive rate limiting
6. MySQL guardrail is currently warning-first, not fail-closed

## Operational Notes

- The current abuse-control implementation is intentionally conservative.
- It is designed to provide lightweight protection without breaking Trojan fallback semantics.
- If the service is deployed behind NAT, CDN, or reverse proxy layers, IP-based controls may need upstream-aware adjustments.

## Recommended Next Steps

1. Add a short operator guide for abuse-control tuning
2. Consider fallback-specific connect timeout tuning
3. Consider exposing runtime metrics in a machine-readable form
4. Evaluate whether remote MySQL should support a strict fail-closed mode
