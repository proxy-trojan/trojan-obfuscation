# Runbook: Two-Host Trusted-Front First Execution

## Purpose

Provide the first concrete execution flow for a two-host trusted-front staging attempt.

## Host roles
- **Host A:** trusted front / front-side sender
- **Host B:** `trojan-obfuscation` backend candidate

## Prerequisite bundle
Generate a staging bundle first:

```bash
./scripts/prepare-two-host-trusted-front-staging.sh
```

## Optional preflight — Local dry run

Before a real two-host run, you can verify the execution flow locally:

```bash
./scripts/run-two-host-trusted-front-local-dry-run.sh \
  <bundle_dir> \
  ./build/ci/trojan
```

This does **not** replace the real two-host run, but it helps catch obvious orchestration mistakes early.

## Step 1 — Start backend candidate on Host B

```bash
./scripts/start-trusted-front-backend-candidate.sh \
  <bundle_dir> \
  ./build/ci/trojan \
  /path/to/public/server.crt \
  /path/to/public/server.key \
  <fallback_addr> \
  <fallback_port> \
  0.0.0.0 \
  443 \
  0.0.0.0 \
  9443 \
  <password>
```

## Step 2 — Run front-side check on Host A

```bash
./scripts/run-trusted-front-front-check.sh \
  <bundle_dir> \
  <backend_host> \
  9443 \
  localhost
```

## Step 3 — Collect evidence
At minimum capture:
- backend log
- backend config snapshot
- front response file
- any passive/public observation notes
- rollback notes
- runtime metrics summary line
- first trusted-front admission / metadata / ingress rejection signal seen

Helpful references while reading evidence:
- `docs/runbooks/operator-signals.md`
- `docs/runbooks/candidate-log-reading.md`
- `docs/runbooks/rollback-verification.md`

## Step 4 — Stop backend candidate when done

```bash
./scripts/stop-trusted-front-backend-candidate.sh <bundle_dir>
```

## Important note
This runbook helps execute the first two-host staging attempt.
It does **not** prove first-tier status by itself.
That still requires a candidate-vs-baseline comparison under the Phase 4 workflow.
