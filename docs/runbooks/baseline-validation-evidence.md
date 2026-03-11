# Runbook: Collect Baseline Validation Evidence

## Purpose

Capture a small, repeatable evidence bundle for the current embedded-TLS baseline.

This runbook is intended to support:
- `docs/baseline-validation-report.md`
- `docs/detectability-validation-workflow.md`
- later before/after comparison against a trusted-front staging candidate

## What It Produces

The script creates an output directory under:
- `build/validation/`

The evidence bundle includes at least:
- `summary.md`
- `openssl-s_client.txt`
- `curl-headers.txt`
- `curl-body.txt`
- `server.log`
- `ctest.txt` (when `build/ci` exists)

## Prerequisites

- built Trojan binary at `build/ci/trojan`
- `python3`
- `openssl`
- `curl`
- optional: `ctest`

## Command

```bash
./scripts/collect-baseline-validation-evidence.sh
```

## Optional arguments

```bash
./scripts/collect-baseline-validation-evidence.sh <trojan-binary> <output-dir>
```

Example:

```bash
./scripts/collect-baseline-validation-evidence.sh \
  ./build/ci/trojan \
  ./build/validation/manual-baseline-check
```

## What The Script Does

1. creates a temporary localhost certificate
2. starts a small local fallback stub
3. starts the Trojan server in embedded-TLS baseline mode
4. captures a local `openssl s_client` snapshot
5. captures a local HTTPS request through the baseline listener
6. copies server logs and optional `ctest` output into the evidence bundle

## Verify

After the script finishes, confirm:
- `summary.md` exists
- `server.log` exists
- `curl-headers.txt` shows an HTTP response
- `openssl-s_client.txt` contains a completed TLS session transcript
- `ctest.txt` exists if `build/ci` was available

## Important Limits

This runbook collects a **local baseline snapshot** only.
It does not prove:
- internet-scale detectability resistance
- first-tier camouflage quality
- trusted-front deployment value

It is a baseline evidence capture tool, not a final comparison result.

## Recommended Next Step

Use the same evidence shape later for:
- mainstream Trojan/TLS comparison
- trusted-front staging candidate comparison
