#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 6 ]]; then
  echo "usage: $0 <bundle_dir> <trojan_bin> <public_cert> <public_key> <fallback_addr> <fallback_port> [public_addr] [public_port] [trusted_addr] [trusted_port] [password]" >&2
  exit 2
fi

BUNDLE_DIR="$1"
TROJAN_BIN="$2"
PUBLIC_CERT="$3"
PUBLIC_KEY="$4"
FALLBACK_ADDR="$5"
FALLBACK_PORT="$6"
PUBLIC_ADDR="${7:-0.0.0.0}"
PUBLIC_PORT="${8:-443}"
TRUSTED_ADDR="${9:-0.0.0.0}"
TRUSTED_PORT="${10:-9443}"
PASSWORD="${11:-replace-me}"

if [[ ! -x "$TROJAN_BIN" ]]; then
  echo "trojan binary not executable: $TROJAN_BIN" >&2
  exit 2
fi

CA_FILE="$BUNDLE_DIR/shared/ca.crt"
TF_CERT="$BUNDLE_DIR/backend/trusted-front-server.crt"
TF_KEY="$BUNDLE_DIR/backend/trusted-front-server.key"
CONFIG_OUT="$BUNDLE_DIR/backend/backend-candidate.runtime.json"
LOG_OUT="$BUNDLE_DIR/backend/backend-candidate.log"
STDOUT_OUT="$BUNDLE_DIR/backend/backend-candidate.stdout"
PID_OUT="$BUNDLE_DIR/backend/backend-candidate.pid"

for path in "$CA_FILE" "$TF_CERT" "$TF_KEY" "$PUBLIC_CERT" "$PUBLIC_KEY"; do
  if [[ ! -f "$path" ]]; then
    echo "missing required file: $path" >&2
    exit 2
  fi
done

mkdir -p "$BUNDLE_DIR/backend"

cat > "$CONFIG_OUT" <<EOF
{
  "run_type": "server",
  "local_addr": "$PUBLIC_ADDR",
  "local_port": $PUBLIC_PORT,
  "remote_addr": "$FALLBACK_ADDR",
  "remote_port": $FALLBACK_PORT,
  "password": ["$PASSWORD"],
  "log_level": 0,
  "ssl": {
    "cert": "$PUBLIC_CERT",
    "key": "$PUBLIC_KEY",
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
    "require_trusted_front_loopback_source": false,
    "trusted_front_listener_addr": "$TRUSTED_ADDR",
    "trusted_front_listener_port": $TRUSTED_PORT,
    "trusted_front_tls_cert": "$TF_CERT",
    "trusted_front_tls_key": "$TF_KEY",
    "trusted_front_tls_key_password": "",
    "trusted_front_tls_ca": "$CA_FILE"
  }
}
EOF

if [[ -f "$PID_OUT" ]]; then
  old_pid=$(cat "$PID_OUT" 2>/dev/null || true)
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    echo "backend candidate already running with pid $old_pid" >&2
    exit 1
  fi
fi

"$TROJAN_BIN" -c "$CONFIG_OUT" -l "$LOG_OUT" > "$STDOUT_OUT" 2>&1 &
echo $! > "$PID_OUT"

python3 - <<'PY' "$TRUSTED_ADDR" "$TRUSTED_PORT"
import socket, sys, time
addr = sys.argv[1]
port = int(sys.argv[2])
deadline = time.time() + 10
while time.time() < deadline:
    try:
        with socket.create_connection((addr, port), timeout=0.5):
            raise SystemExit(0)
    except OSError:
        time.sleep(0.1)
raise SystemExit('trusted-front listener did not start in time')
PY

echo "started trusted-front backend candidate"
echo "config=$CONFIG_OUT"
echo "log=$LOG_OUT"
echo "stdout=$STDOUT_OUT"
echo "pid=$(cat "$PID_OUT")"
