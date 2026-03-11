# Baseline Validation Report

## Status

Draft

## Validation Run Type

Baseline snapshot

## Date

2026-03-11

## Target

- **Name:** Embedded TLS + fallback baseline
- **Shape:** Single-host local validation harness
- **Public entry:** Direct backend TLS listener
- **Backend entry:** No trusted external front
- **Fallback behavior:** Local fallback backend stub over the configured `remote_addr` / `remote_port`
- **Rollback method:** Baseline mode is already the default posture; keep `external_front.enabled = false`

## Scope

This report validates the current project’s baseline posture before any real trusted-front rollout work.

It focuses on:
- passive public TLS surface basics
- active probing signals already exercised by tests
- fallback/public-surface behavior
- operator-visible signals

It does **not** attempt to prove:
- real-world censorship resistance
- production-grade camouflage quality
- first-tier public-edge posture

---

# 1. Evidence Collected

## A. Automated baseline checks

A local baseline test run was executed with:

```bash
ctest --test-dir build/ci --output-on-failure -j2
```

### Result
- `RuntimeSeamTests` — passed
- `LinuxSmokeTest-basic` — passed
- `LinuxSmokeTest-auth-fail-cooldown` — passed
- `LinuxSmokeTest-server-config-fails` — passed
- `LinuxSmokeTest-fallback-budget` — passed

### Summary
- **5/5 tests passed**

### What these tests demonstrate
- the baseline binary and example config paths behave as expected
- invalid authentication attempts can trigger cooldown logic
- fallback slot budgeting works and rejects over-budget fallback usage
- baseline server configuration failure behavior is predictable when placeholder certificate paths are present

---

## B. Local passive/public-surface probe

A local temporary baseline server was started with:
- self-signed localhost certificate
- embedded TLS enabled
- local fallback backend stub
- `http/1.1` ALPN configured

### `openssl s_client` observation
Observed from a local TLS connection:
- TLS listener accepted the connection
- server exposed a direct backend certificate with `CN=localhost`
- certificate was self-signed in the local harness

### Interpretation
This confirms the expected baseline shape:
- the public-facing TLS surface is **the backend itself**
- there is **no front separation** in the baseline posture

This is structurally correct for the current baseline, but it also confirms why the current baseline is not yet first-tier in public-edge camouflage.

---

## C. Local fallback/public behavior probe

A local HTTPS request was sent through the baseline listener:

```text
GET / HTTP/1.1
Host: localhost
```

### Observed response
```http
HTTP/1.1 200 OK
Content-Type: text/plain
Content-Length: 18
Connection: close

baseline-fallback
```

### Interpretation
This confirms that:
- non-Trojan request handling can flow into fallback behavior
- the public-facing response can remain coherent rather than simply dropping the connection
- fallback remains a meaningful part of the baseline public-surface story

### Important limit
This local fallback stub is still only a **minimal realism check**.
It does not prove that the fallback surface is sufficiently believable for production-grade camouflage.

---

## D. Operator log evidence from local baseline run

Observed server log lines included:

```text
SSL handshake failed: stream truncated
not trojan request, connecting to 127.0.0.1:<port>
tunnel established
```

### Interpretation
This confirms that operators can currently observe:
- malformed / incomplete TLS handshakes
- fallback path selection for non-Trojan requests
- successful fallback tunnel establishment

This is useful for operations and debugging.
It does **not** automatically mean the external behavior is ideal against hostile probing.
It only confirms that the baseline path is explainable from the operator side.

---

## E. Existing active-probing-related smoke coverage

The current baseline test suite already exercises several active-probing-adjacent behaviors:

### Authentication failure cooldown
Smoke test behavior demonstrates:
- repeated invalid auth attempts trigger cooldown
- later connections from the same IP are rejected during cooldown

### Fallback budget exhaustion
Smoke test behavior demonstrates:
- fallback sessions consume a dedicated budget
- over-budget fallback attempts are rejected with a stable reason

### Interpretation
These tests strengthen confidence that the baseline path has:
- defensive runtime behavior
- stable rejection paths
- operator-visible failure semantics

---

# 2. Passive Observation Summary

## Summary
The current baseline exposes a **direct backend TLS surface**.

## What looks acceptable
- TLS listener works as expected
- fallback can produce a coherent public response
- operator-visible signals are present

## What remains suspicious or limited
- no front separation
- no ECH
- no browser-like edge behavior
- no evidence yet of a stronger public-edge disguise class

## Practical conclusion
The baseline behaves like a serious Trojan/TLS deployment, not like a front-separated or browser-mimicking public edge.

---

# 3. Active Probing Summary

## Summary
The current baseline appears to have meaningful guardrails, but its public edge is still fundamentally a direct backend TLS endpoint.

## Evidence available now
- invalid auth can trigger cooldown
- malformed or incomplete handshakes are noticed and logged
- non-Trojan HTTP-like traffic can be pushed into fallback behavior
- fallback budget exhaustion is enforced and logged

## What is still missing
- packet-level comparison against mainstream alternatives
- external probe harness beyond local smoke scripts
- repeated passive-fingerprint collection over realistic deployment environments

## Practical conclusion
The baseline is **operationally disciplined**, but not yet validated as first-tier against stronger real-world probing models.

---

# 4. Public-Surface Realism Summary

## Summary
Fallback exists and works, which is materially better than simply closing the connection.

## Positive signals
- fallback path is reachable
- fallback response can look coherent
- fallback slot protection exists

## Limits
- local fallback stub is too small to count as production realism proof
- this report does not validate a real content backend or realistic front-end application surface

## Practical conclusion
Fallback behavior is a real strength of the baseline, but realism quality still depends on deployment discipline.

---

# 5. Operator Signals Summary

## Available signals
The current baseline already provides operator-useful signals such as:
- authentication failure threshold reached / cooldown
- connection rejected due to cooldown
- fallback path selection
- fallback budget exhaustion
- runtime metrics for fallback and session counts

## Why this matters
This is one of the project’s current strengths:
- the baseline is not only deployable
- it is also explainable and monitorable

## Remaining gap
Operator visibility is stronger than the project’s current public-edge camouflage posture.
That is useful, but it also highlights that the next big gains likely come from edge shape rather than more backend-only structure work.

---

# 6. Verdict

## Rating
**Strong second-tier practical baseline**

## Why
Because the current baseline shows:
- stable runtime behavior
- meaningful fallback handling
- useful operator-visible signals
- guarded rejection paths
- clean local test coverage

But it also clearly remains:
- a direct backend TLS surface
- without real front separation
- without first-tier public-edge camouflage characteristics

## Short version
- against ordinary Trojan/TLS-class baselines: **competitive**
- against first-tier front-separated / browser-like systems: **still behind**

---

# 7. Recommended Next Action

## Immediate next validation step
Run the same workflow against:
1. one reference mainstream Trojan/TLS deployment
2. one trusted-front staging candidate once topology gates are ready

## Decision implication
This report supports the current Phase 4 direction:
- keep the embedded-TLS baseline as the mainline deliverable
- pursue stronger public-edge posture through trusted-front staging, not backend protocol sprawl

## What should not be concluded from this report
Do **not** conclude that the project is already first-tier in camouflage.
This report only establishes a grounded baseline snapshot.
