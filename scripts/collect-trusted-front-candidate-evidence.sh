#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TROJAN_BIN="${1:-$PROJECT_ROOT/build/ci/trojan}"
OUT_DIR="${2:-$PROJECT_ROOT/build/validation/trusted-front-candidate-$(date +%Y%m%d-%H%M%S)}"

if [[ ! -x "$TROJAN_BIN" ]]; then
  echo "trojan binary not found or not executable: $TROJAN_BIN" >&2
  exit 2
fi

for cmd in python3 openssl curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing dependency: $cmd" >&2
    exit 2
  fi
done

mkdir -p "$OUT_DIR"
TMPDIR="$(mktemp -d)"
HTTP_PID=""
TROJAN_PID=""
cleanup() {
  for pid in "$HTTP_PID" "$TROJAN_PID"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

read -r PUBLIC_PORT TRUSTED_FRONT_PORT REMOTE_PORT < <(python3 - <<'PY'
import socket
ports = []
for _ in range(3):
    s = socket.socket()
    s.bind(('127.0.0.1', 0))
    ports.append(s.getsockname()[1])
    s.close()
print(*ports)
PY
)

# CA
openssl genrsa -out "$TMPDIR/ca.key" 2048 >/dev/null 2>&1
openssl req -x509 -new -nodes -key "$TMPDIR/ca.key" -sha256 -days 1 -out "$TMPDIR/ca.crt" -subj "/CN=trusted-front-ca" >/dev/null 2>&1

# Public/backend cert
openssl genrsa -out "$TMPDIR/server.key" 2048 >/dev/null 2>&1
openssl req -new -key "$TMPDIR/server.key" -out "$TMPDIR/server.csr" -subj "/CN=localhost" >/dev/null 2>&1
openssl x509 -req -in "$TMPDIR/server.csr" -CA "$TMPDIR/ca.crt" -CAkey "$TMPDIR/ca.key" -CAcreateserial -out "$TMPDIR/server.crt" -days 1 -sha256 >/dev/null 2>&1

# Client cert for mTLS internal hop
openssl genrsa -out "$TMPDIR/client.key" 2048 >/dev/null 2>&1
openssl req -new -key "$TMPDIR/client.key" -out "$TMPDIR/client.csr" -subj "/CN=trusted-front-client" >/dev/null 2>&1
openssl x509 -req -in "$TMPDIR/client.csr" -CA "$TMPDIR/ca.crt" -CAkey "$TMPDIR/ca.key" -CAcreateserial -out "$TMPDIR/client.crt" -days 1 -sha256 >/dev/null 2>&1

printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 26\r\nConnection: close\r\n\r\ntrusted-front-candidate\n" > "$TMPDIR/response.txt"

python3 - <<'PY' "$REMOTE_PORT" "$TMPDIR/response.txt" >"$OUT_DIR/fallback-server.log" 2>&1 &
import pathlib, socket, sys
port = int(sys.argv[1])
body = pathlib.Path(sys.argv[2]).read_bytes()
listener = socket.socket()
listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
listener.bind(('127.0.0.1', port))
listener.listen(5)
while True:
    conn, _ = listener.accept()
    try:
        _ = conn.recv(4096)
        conn.sendall(body)
    finally:
        conn.close()
PY
HTTP_PID=$!

cat > "$TMPDIR/config.json" <<EOF
{
  "run_type": "server",
  "local_addr": "127.0.0.1",
  "local_port": ${PUBLIC_PORT},
  "remote_addr": "127.0.0.1",
  "remote_port": ${REMOTE_PORT},
  "password": ["correct-password"],
  "log_level": 0,
  "ssl": {
    "cert": "$TMPDIR/server.crt",
    "key": "$TMPDIR/server.key",
    "key_password": "",
    "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384",
    "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
    "prefer_server_cipher": true,
    "alpn": ["http/1.1"],
    "alpn_port_override": {},
    "reuse_session": true,
    "session_ticket": false,
    "session_timeout": 600,
    "plain_http_response": "",
    "curves": "",
    "dhparam": ""
  },
  "threads": 1,
  "tcp": {
    "prefer_ipv4": false,
    "no_delay": true,
    "keep_alive": true,
    "reuse_port": false,
    "fast_open": false,
    "fast_open_qlen": 20
  },
  "mysql": {
    "enabled": false,
    "server_addr": "127.0.0.1",
    "server_port": 3306,
    "database": "trojan",
    "username": "trojan",
    "password": "",
    "key": "",
    "cert": "",
    "ca": ""
  },
  "abuse_control": {
    "enabled": true,
    "per_ip_max_connections": 64,
    "auth_fail_window_seconds": 60,
    "auth_fail_max": 20,
    "cooldown_seconds": 60,
    "fallback_max_active": 32
  },
  "external_front": {
    "enabled": true,
    "enable_trusted_front_listener": true,
    "trusted_front_listener_use_mtls": true,
    "require_trusted_front_loopback_source": true,
    "trusted_front_listener_addr": "127.0.0.1",
    "trusted_front_listener_port": ${TRUSTED_FRONT_PORT},
    "trusted_front_tls_cert": "$TMPDIR/server.crt",
    "trusted_front_tls_key": "$TMPDIR/server.key",
    "trusted_front_tls_key_password": "",
    "trusted_front_tls_ca": "$TMPDIR/ca.crt"
  }
}
EOF

"$TROJAN_BIN" -c "$TMPDIR/config.json" -l "$OUT_DIR/server.log" >"$OUT_DIR/server.stdout" 2>&1 &
TROJAN_PID=$!

python3 - <<'PY' "$TRUSTED_FRONT_PORT"
import socket, sys, time
port = int(sys.argv[1])
deadline = time.time() + 10
while time.time() < deadline:
    try:
        with socket.create_connection(('127.0.0.1', port), timeout=0.5):
            raise SystemExit(0)
    except OSError:
        time.sleep(0.1)
raise SystemExit('trusted-front listener did not start in time')
PY

{
  echo "# Trusted-Front Candidate Validation Evidence"
  echo
  echo "- Generated: $(date -Iseconds)"
  echo "- Trojan binary: $TROJAN_BIN"
  echo "- Output dir: $OUT_DIR"
  echo "- Public baseline port: $PUBLIC_PORT"
  echo "- Trusted-front listener port: $TRUSTED_FRONT_PORT"
  echo "- Fallback port: $REMOTE_PORT"
} > "$OUT_DIR/summary.md"

# Observe internal mTLS listener handshake
printf '' | openssl s_client \
  -connect 127.0.0.1:${TRUSTED_FRONT_PORT} \
  -servername localhost \
  -cert "$TMPDIR/client.crt" \
  -key "$TMPDIR/client.key" \
  -CAfile "$TMPDIR/ca.crt" > "$OUT_DIR/openssl-s_client-trusted-front.txt" 2>&1 || true

# Send a trusted-front ingress frame carrying a simple downstream HTTP payload.
cat > "$TMPDIR/envelope.json" <<'EOF'
{"source_name":"local-trusted-front","trusted_front_id":"local-front-id","original_client_ip":"203.0.113.10","original_client_port":44321,"server_name":"front.example.com","negotiated_alpn":"h2","tls_terminated_by_front":true,"metadata_verified":true}
EOF
printf 'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n' > "$TMPDIR/downstream.txt"
python3 "$PROJECT_ROOT/scripts/send-trusted-front-frame.py" \
  --host 127.0.0.1 \
  --port "$TRUSTED_FRONT_PORT" \
  --server-name localhost \
  --ca "$TMPDIR/ca.crt" \
  --cert "$TMPDIR/client.crt" \
  --key "$TMPDIR/client.key" \
  --envelope-json-file "$TMPDIR/envelope.json" \
  --payload-file "$TMPDIR/downstream.txt" \
  --output "$OUT_DIR/client-transport.raw" > /dev/null 2>&1 || true
python3 - <<'PY' "$OUT_DIR/client-transport.raw" > "$OUT_DIR/client-transport.txt" 2>&1
import pathlib, sys
path = pathlib.Path(sys.argv[1])
if not path.exists() or not path.read_bytes():
    print('[no immediate downstream response captured]')
else:
    print(path.read_text(errors='replace'))
PY

if command -v ctest >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/build/ci/CTestTestfile.cmake" ]]; then
  ctest --test-dir "$PROJECT_ROOT/build/ci" --output-on-failure -j2 > "$OUT_DIR/ctest.txt" 2>&1 || true
fi

echo "wrote trusted-front candidate validation evidence to: $OUT_DIR"
