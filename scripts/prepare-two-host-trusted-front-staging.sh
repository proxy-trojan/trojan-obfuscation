#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${1:-$PROJECT_ROOT/build/staging/two-host-trusted-front-$(date +%Y%m%d-%H%M%S)}"

for cmd in openssl python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing dependency: $cmd" >&2
    exit 2
  fi
done

mkdir -p "$OUT_DIR/front" "$OUT_DIR/backend" "$OUT_DIR/shared"

# Shared CA
openssl genrsa -out "$OUT_DIR/shared/ca.key" 2048 >/dev/null 2>&1
openssl req -x509 -new -nodes -key "$OUT_DIR/shared/ca.key" -sha256 -days 7 -out "$OUT_DIR/shared/ca.crt" -subj "/CN=trusted-front-staging-ca" >/dev/null 2>&1

# Backend listener cert
openssl genrsa -out "$OUT_DIR/backend/trusted-front-server.key" 2048 >/dev/null 2>&1
openssl req -new -key "$OUT_DIR/backend/trusted-front-server.key" -out "$OUT_DIR/backend/trusted-front-server.csr" -subj "/CN=trusted-front-backend" >/dev/null 2>&1
openssl x509 -req -in "$OUT_DIR/backend/trusted-front-server.csr" -CA "$OUT_DIR/shared/ca.crt" -CAkey "$OUT_DIR/shared/ca.key" -CAcreateserial -out "$OUT_DIR/backend/trusted-front-server.crt" -days 7 -sha256 >/dev/null 2>&1

# Front client cert
openssl genrsa -out "$OUT_DIR/front/trusted-front-client.key" 2048 >/dev/null 2>&1
openssl req -new -key "$OUT_DIR/front/trusted-front-client.key" -out "$OUT_DIR/front/trusted-front-client.csr" -subj "/CN=trusted-front-client" >/dev/null 2>&1
openssl x509 -req -in "$OUT_DIR/front/trusted-front-client.csr" -CA "$OUT_DIR/shared/ca.crt" -CAkey "$OUT_DIR/shared/ca.key" -CAcreateserial -out "$OUT_DIR/front/trusted-front-client.crt" -days 7 -sha256 >/dev/null 2>&1

cat > "$OUT_DIR/backend/backend-candidate-config.template.json" <<'EOF'
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 443,
  "remote_addr": "127.0.0.1",
  "remote_port": 8080,
  "password": ["REPLACE_ME"],
  "ssl": {
    "cert": "/path/to/public/server.crt",
    "key": "/path/to/public/server.key",
    "key_password": ""
  },
  "external_front": {
    "enabled": true,
    "enable_trusted_front_listener": true,
    "trusted_front_listener_use_mtls": true,
    "require_trusted_front_loopback_source": false,
    "trusted_front_listener_addr": "0.0.0.0",
    "trusted_front_listener_port": 9443,
    "trusted_front_tls_cert": "/path/to/backend/trusted-front-server.crt",
    "trusted_front_tls_key": "/path/to/backend/trusted-front-server.key",
    "trusted_front_tls_key_password": "",
    "trusted_front_tls_ca": "/path/to/shared/ca.crt"
  }
}
EOF

cat > "$OUT_DIR/front/front-transport-notes.md" <<'EOF'
# Front Transport Notes

This directory represents the trusted-front side of the first two-host staging run.

## What the front must do
- terminate or shape the public-facing edge behavior under test
- establish the internal mTLS connection to the backend trusted-front listener
- transmit a trusted-front envelope followed by downstream payload

## Current project state
The backend currently supports:
- trusted-front envelope parsing
- trusted-front ingress frame parsing
- trusted-front runtime bootstrap path
- internal trusted-front listener wiring
- mTLS-capable trusted-front listener shape

## Next step for actual execution
Implement or script a front-side transport sender that:
1. opens mTLS connection to backend trusted-front listener
2. writes `<envelope_length>\n<json_envelope><downstream_payload>`
3. captures backend response and logs
EOF

cat > "$OUT_DIR/README.md" <<'EOF'
# Two-Host Trusted-Front Staging Bundle

This bundle was generated to prepare the first real two-host trusted-front staging execution.

## Contents
- `shared/` — staging CA and shared trust material
- `backend/` — backend trusted-front listener certs and config template
- `front/` — client certs and front transport notes

## What this bundle is for
- preparing a real two-host trusted-front staging attempt
- making trust material generation repeatable
- reducing staging setup friction before evidence capture

## What this bundle does NOT mean
- production rollout readiness
- first-tier status
- proven detectability improvement
EOF

echo "prepared two-host trusted-front staging bundle at: $OUT_DIR"
