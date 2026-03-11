# Runbook: Send Trusted-Front Frame

## Purpose

Provide a small front-side helper for trusted-front staging and candidate validation.

This script is intended to represent the minimum front transport behavior required by the current trusted-front candidate path.

## Script

```bash
python3 scripts/send-trusted-front-frame.py
```

## What it does

The script:
1. opens an mTLS connection to the backend trusted-front listener
2. sends a trusted-front ingress frame in this format:

```text
<envelope_length>\n<json_envelope><downstream_payload>
```

3. captures any immediate downstream response

## Required inputs
- backend host
- backend trusted-front listener port
- CA file
- client cert
- client key
- trusted-front envelope JSON
- downstream payload

## Example

```bash
python3 scripts/send-trusted-front-frame.py \
  --host 127.0.0.1 \
  --port 9443 \
  --server-name localhost \
  --ca ./shared/ca.crt \
  --cert ./front/trusted-front-client.crt \
  --key ./front/trusted-front-client.key \
  --envelope-json-file ./front/envelope.json \
  --payload-file ./front/downstream.txt \
  --output ./front/response.raw
```

## Important limits

This script is only a **minimum staging transport sender**.
It does not attempt to be:
- a production front implementation
- an HTTP reverse proxy
- a browser-like front
- a final trusted-front transport design

## Why it matters

The current trusted-front candidate is only meaningful if Host A can actually send:
- a valid envelope
- a downstream payload
- over the internal mTLS boundary

This helper keeps that requirement concrete and testable.
