#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TROJAN_BIN="${1:-$PROJECT_ROOT/build/ci/trojan}"
OUT_DIR="${2:-$PROJECT_ROOT/build/validation/baseline-$(date +%Y%m%d-%H%M%S)}"

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

read -r TROJAN_PORT REMOTE_PORT < <(python3 - <<'PY'
import socket
ports = []
for _ in range(2):
    s = socket.socket()
    s.bind(('127.0.0.1', 0))
    ports.append(s.getsockname()[1])
    s.close()
print(ports[0], ports[1])
PY
)

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TMPDIR/server.key" \
  -out "$TMPDIR/server.crt" \
  -days 1 \
  -subj "/CN=localhost" >/dev/null 2>&1

printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 18\r\nConnection: close\r\n\r\nbaseline-fallback\n" > "$TMPDIR/response.txt"

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
  "local_port": ${TROJAN_PORT},
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
  }
}
EOF

cp "$TMPDIR/config.json" "$OUT_DIR/config.snapshot.json"
"$PROJECT_ROOT/scripts/check-profile-mode.sh" --json "$TMPDIR/config.json" > "$OUT_DIR/profile-mode.json"
"$PROJECT_ROOT/scripts/check-profile-mode.sh" "$TMPDIR/config.json" > "$OUT_DIR/profile-mode.txt"

"$TROJAN_BIN" -c "$TMPDIR/config.json" -l "$OUT_DIR/server.log" >"$OUT_DIR/server.stdout" 2>&1 &
TROJAN_PID=$!

python3 - <<'PY' "$TROJAN_PORT"
import socket, sys, time
port = int(sys.argv[1])
deadline = time.time() + 10
while time.time() < deadline:
    try:
        with socket.create_connection(('127.0.0.1', port), timeout=0.5):
            raise SystemExit(0)
    except OSError:
        time.sleep(0.1)
raise SystemExit('server did not start listening in time')
PY

GENERATED_AT="$(date -Iseconds)"

{
  echo "# Baseline Validation Evidence"
  echo
  echo "- Generated: $GENERATED_AT"
  echo "- Trojan binary: $TROJAN_BIN"
  echo "- Output dir: $OUT_DIR"
  echo "- Local port: $TROJAN_PORT"
  echo "- Fallback port: $REMOTE_PORT"
  echo "- Config snapshot: $OUT_DIR/config.snapshot.json"
  echo "- Profile mode: $OUT_DIR/profile-mode.json"
} > "$OUT_DIR/summary.md"

python3 - <<'PY' "$OUT_DIR/summary.json" "$GENERATED_AT" "$TROJAN_BIN" "$OUT_DIR" "$TROJAN_PORT" "$REMOTE_PORT" "$OUT_DIR/profile-mode.json"
import json
import pathlib
import sys

summary_path = pathlib.Path(sys.argv[1])
generated_at = sys.argv[2]
trojan_bin = sys.argv[3]
out_dir = sys.argv[4]
trojan_port = int(sys.argv[5])
remote_port = int(sys.argv[6])
profile_mode = json.loads(pathlib.Path(sys.argv[7]).read_text())

summary = {
    "artifact_paths": {
        "config_snapshot": f"{out_dir}/config.snapshot.json",
        "curl_body": f"{out_dir}/curl-body.txt",
        "curl_headers": f"{out_dir}/curl-headers.txt",
        "openssl_s_client": f"{out_dir}/openssl-s_client.txt",
        "profile_mode": f"{out_dir}/profile-mode.json",
        "server_log": f"{out_dir}/server.log",
        "server_stdout": f"{out_dir}/server.stdout",
        "summary_md": f"{out_dir}/summary.md"
    },
    "generated_at": generated_at,
    "out_dir": out_dir,
    "ports": {
        "fallback": remote_port,
        "public": trojan_port
    },
    "profile_label": "baseline",
    "profile_mode": profile_mode,
    "trojan_bin": trojan_bin
}

summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
PY

printf '' | openssl s_client -connect 127.0.0.1:${TROJAN_PORT} -servername localhost -alpn http/1.1 > "$OUT_DIR/openssl-s_client.txt" 2>&1 || true
curl -ksS https://localhost:${TROJAN_PORT}/ -D "$OUT_DIR/curl-headers.txt" -o "$OUT_DIR/curl-body.txt" || true

if command -v ctest >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/build/ci/CTestTestfile.cmake" ]]; then
  ctest --test-dir "$PROJECT_ROOT/build/ci" --output-on-failure -j2 > "$OUT_DIR/ctest.txt" 2>&1 || true
fi

echo "wrote baseline validation evidence to: $OUT_DIR"
