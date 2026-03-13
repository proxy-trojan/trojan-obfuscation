#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT_DIR="$ROOT_DIR/client"
SMOKE_WINDOW_SECONDS="${SMOKE_WINDOW_SECONDS:-8}"
KEEP_SMOKE_ARTIFACTS="${KEEP_SMOKE_ARTIFACTS:-0}"
DEFAULT_TROJAN_CANDIDATES=(
  "$ROOT_DIR/build/ci-local/trojan"
  "$ROOT_DIR/build/ci/trojan"
  "$ROOT_DIR/build/scan/trojan"
  trojan
)

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

choose_free_port() {
  python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
}

detect_trojan_binary() {
  if [[ -n "${TROJAN_CLIENT_BINARY:-}" ]]; then
    echo "$TROJAN_CLIENT_BINARY"
    return
  fi

  local candidate
  for candidate in "${DEFAULT_TROJAN_CANDIDATES[@]}"; do
    if [[ "$candidate" == *"/"* ]]; then
      if [[ -x "$candidate" ]]; then
        echo "$candidate"
        return
      fi
      continue
    fi

    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return
    fi
  done

  echo "unable to locate trojan binary; set TROJAN_CLIENT_BINARY explicitly" >&2
  exit 1
}

launch_gui_smoke() {
  local log_path="$1"
  shift

  if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    "$@" >"$log_path" 2>&1 &
  elif command -v xvfb-run >/dev/null 2>&1; then
    xvfb-run -a "$@" >"$log_path" 2>&1 &
  else
    return 125
  fi

  local app_pid=$!
  sleep "$SMOKE_WINDOW_SECONDS"

  if ! kill -0 "$app_pid" 2>/dev/null; then
    wait "$app_pid"
    return 1
  fi

  kill "$app_pid" 2>/dev/null || true
  wait "$app_pid" || true
  return 0
}

check_port_listening() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltn | grep -q ":${port}\b"
  elif command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"$port" -sTCP:LISTEN -P -n >/dev/null 2>&1
  else
    echo "no port-check tool available (need ss or lsof)" >&2
    return 1
  fi
}

need_cmd flutter
need_cmd python3
need_cmd timeout

TROJAN_BINARY="$(detect_trojan_binary)"
TEMP_DIR="$(mktemp -d)"
PORT="${TROJAN_CLIENT_SMOKE_PORT:-$(choose_free_port)}"
CONFIG_PATH="$TEMP_DIR/runtime-smoke-client.json"
TROJAN_STDOUT_LOG="$TEMP_DIR/trojan.stdout.log"
TROJAN_STDERR_LOG="$TEMP_DIR/trojan.stderr.log"
APP_LOG="$TEMP_DIR/client-app.log"
APP_BINARY="$CLIENT_DIR/build/linux/x64/debug/bundle/trojan_pro_client"
GUI_STATUS="not-run"

cleanup() {
  if [[ -n "${TROJAN_PID:-}" ]] && kill -0 "$TROJAN_PID" 2>/dev/null; then
    kill "$TROJAN_PID" 2>/dev/null || true
    wait "$TROJAN_PID" || true
  fi
  if [[ "$KEEP_SMOKE_ARTIFACTS" == "1" ]]; then
    echo "keeping smoke artifacts: $TEMP_DIR"
  else
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

cat >"$CONFIG_PATH" <<JSON
{
  "run_type": "client",
  "local_addr": "127.0.0.1",
  "local_port": $PORT,
  "remote_addr": "example.com",
  "remote_port": 443,
  "password": ["demo-pass"],
  "log_level": 1,
  "ssl": {
    "verify": true,
    "verify_hostname": true,
    "cert": "",
    "sni": "example.com",
    "alpn": ["h2", "http/1.1"],
    "reuse_session": true,
    "session_ticket": false,
    "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256",
    "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256",
    "curves": ""
  },
  "tcp": {
    "no_delay": true,
    "keep_alive": true,
    "reuse_port": false,
    "fast_open": false,
    "fast_open_qlen": 20
  }
}
JSON

echo "==> client runtime smoke: analyze / test / build"
cd "$CLIENT_DIR"
flutter analyze
flutter test
flutter build linux --debug

if [[ ! -x "$APP_BINARY" ]]; then
  echo "expected debug bundle executable missing: $APP_BINARY" >&2
  exit 1
fi

echo "==> trojan binary version"
"$TROJAN_BINARY" -v

echo "==> trojan client runtime preflight"
"$TROJAN_BINARY" -c "$CONFIG_PATH" >"$TROJAN_STDOUT_LOG" 2>"$TROJAN_STDERR_LOG" &
TROJAN_PID=$!
sleep 2

if ! kill -0 "$TROJAN_PID" 2>/dev/null; then
  echo "trojan client process exited unexpectedly during preflight" >&2
  echo "--- trojan stdout ---" >&2
  sed -n '1,120p' "$TROJAN_STDOUT_LOG" >&2 || true
  echo "--- trojan stderr ---" >&2
  sed -n '1,120p' "$TROJAN_STDERR_LOG" >&2 || true
  exit 1
fi

if ! check_port_listening "$PORT"; then
  echo "trojan client did not open expected local port: $PORT" >&2
  echo "--- trojan stdout ---" >&2
  sed -n '1,120p' "$TROJAN_STDOUT_LOG" >&2 || true
  echo "--- trojan stderr ---" >&2
  sed -n '1,120p' "$TROJAN_STDERR_LOG" >&2 || true
  exit 1
fi

kill "$TROJAN_PID" 2>/dev/null || true
wait "$TROJAN_PID" || true
unset TROJAN_PID

echo "==> app launch smoke"
export TROJAN_CLIENT_ENABLE_REAL_ADAPTER=1
export TROJAN_CLIENT_BINARY="$TROJAN_BINARY"
set +e
launch_gui_smoke "$APP_LOG" "$APP_BINARY"
APP_RC=$?
set -e

case "$APP_RC" in
  0)
    GUI_STATUS="passed (app stayed alive for ${SMOKE_WINDOW_SECONDS}s smoke window)"
    ;;
  125)
    GUI_STATUS="skipped (no DISPLAY / WAYLAND_DISPLAY and xvfb-run unavailable)"
    ;;
  *)
    echo "client app failed to stay alive during GUI smoke window" >&2
    echo "--- client app log ---" >&2
    sed -n '1,160p' "$APP_LOG" >&2 || true
    exit 1
    ;;
esac

echo
echo "client runtime smoke summary"
echo "- trojan binary: $TROJAN_BINARY"
echo "- trojan preflight port: $PORT"
echo "- trojan preflight: passed"
echo "- gui launch: $GUI_STATUS"
echo "- temp dir: $TEMP_DIR"

if [[ "$GUI_STATUS" == skipped* ]]; then
  echo
  echo "note: GUI launch was skipped because this environment is headless."
  echo "      install xvfb-run or provide a real DISPLAY to complete the desktop launch step."
fi
