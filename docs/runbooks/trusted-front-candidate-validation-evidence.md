# Runbook: Collect Trusted-Front Candidate Validation Evidence

## Purpose

Capture a local evidence bundle for the current trusted-front staging candidate path.

This runbook supports:
- `docs/planning/trusted-front-staging-candidate-validation-report.md`
- future candidate validation reports
- before/after comparison against the embedded-TLS baseline

## What It Does

The script:
1. creates a local CA
2. creates server/client certificates for a local mTLS internal hop
3. starts the Trojan server with:
   - public embedded-TLS listener
   - trusted-front internal listener
   - mTLS enabled on the trusted-front listener
4. captures an internal `openssl s_client` snapshot against the trusted-front listener
5. sends a trusted-front ingress frame carrying a downstream payload
6. captures server logs and optional `ctest` output

## Command

```bash
./scripts/collect-trusted-front-candidate-evidence.sh
```

## Optional arguments

```bash
./scripts/collect-trusted-front-candidate-evidence.sh <trojan-binary> <output-dir>
```

## Output

The script writes an evidence bundle under:
- `build/validation/`

Typical files include:
- `summary.md`
- `openssl-s_client-trusted-front.txt`
- `client-transport.txt`
- `server.log`
- `ctest.txt`

## Important Limits

This runbook collects a **local candidate snapshot** only.
It does **not** prove:
- two-host staging readiness
- production trusted-front value
- first-tier public-edge camouflage
- public internet rollout safety

## Recommended Usage

Use this evidence to answer only these questions first:
- does the trusted-front candidate path actually start?
- does the mTLS-capable internal listener work?
- does the candidate path remain compatible with the existing runtime/test baseline?

Only after that should the project move to a stronger staging comparison.
