#!/usr/bin/env bash
set -euo pipefail

TROJAN_BIN="${1:-}"
if [[ -z "$TROJAN_BIN" ]]; then
  echo "usage: $0 <trojan-binary>" >&2
  exit 2
fi

if [[ ! -x "$TROJAN_BIN" ]]; then
  echo "trojan binary not found or not executable: $TROJAN_BIN" >&2
  exit 2
fi

command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 2; }
command -v openssl >/dev/null 2>&1 || { echo "openssl is required" >&2; exit 2; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TMPDIR="$(mktemp -d)"
SERVER_PID=""
REMOTE_HOLDER_PID=""
cleanup() {
  for pid in "$REMOTE_HOLDER_PID" "$SERVER_PID"; do
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
    "fallback_max_active": 1
  }
}
EOF

python3 - <<'PY' "$REMOTE_PORT" >"$TMPDIR/remote-holder.out" 2>&1 &
import socket, sys, time
port = int(sys.argv[1])
listener = socket.socket()
listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
listener.bind(('127.0.0.1', port))
listener.listen(5)
conn, _ = listener.accept()
try:
    time.sleep(8)
finally:
    conn.close()
    listener.close()
PY
REMOTE_HOLDER_PID=$!

"$TROJAN_BIN" -c "$TMPDIR/config.json" -l "$TMPDIR/server.log" >"$TMPDIR/server.stdout" 2>&1 &
SERVER_PID=$!

python3 - <<'PY' "$TROJAN_PORT"
import socket, sys, time
port = int(sys.argv[1])
deadline = time.time() + 10
while time.time() < deadline:
    try:
        with socket.create_connection(('127.0.0.1', port), timeout=0.5):
            sys.exit(0)
    except OSError:
        time.sleep(0.1)
raise SystemExit('server did not start listening in time')
PY

trigger_fallback() {
  python3 - <<'PY' "$TROJAN_PORT"
import socket, ssl, sys, time
port = int(sys.argv[1])
ctx = ssl._create_unverified_context()
payload = b"GET / HTTP/1.1\r\nHost: localhost\r\n\r\n"
with socket.create_connection(('127.0.0.1', port), timeout=3) as sock:
    with ctx.wrap_socket(sock, server_hostname='localhost') as tls:
        tls.sendall(payload)
        time.sleep(2)
PY
}

wait_for_log() {
  local expected="$1"
  python3 - <<'PY' "$TMPDIR/server.log" "$expected"
import pathlib, sys, time
path = pathlib.Path(sys.argv[1])
needle = sys.argv[2]
deadline = time.time() + 10
while time.time() < deadline:
    text = path.read_text(encoding='utf-8', errors='replace') if path.exists() else ''
    if needle in text:
        sys.exit(0)
    time.sleep(0.1)
print(f'missing log line: {needle}', file=sys.stderr)
if path.exists():
    print(path.read_text(encoding='utf-8', errors='replace'), file=sys.stderr)
sys.exit(1)
PY
}

trigger_fallback &
FIRST_PID=$!
wait_for_log "not trojan request, connecting to 127.0.0.1:${REMOTE_PORT}"
trigger_fallback || true
wait_for_log "fallback rejected: active fallback session budget exhausted"
wait "$FIRST_PID"

echo "LinuxSmokeTest-fallback-budget: ok"
