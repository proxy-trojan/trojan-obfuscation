#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <bundle_dir> <trojan_bin> [public_addr] [public_port] [trusted_addr] [trusted_port] [password]" >&2
  exit 2
fi

BUNDLE_DIR="$1"
TROJAN_BIN="$2"
PUBLIC_ADDR="${3:-127.0.0.1}"
PUBLIC_PORT="${4:-8443}"
TRUSTED_ADDR="${5:-127.0.0.1}"
TRUSTED_PORT="${6:-9443}"
PASSWORD="${7:-test-password}"
RUN_DIR="$(cd "$(dirname "$0")/.." && pwd)/build/validation/two-host-dry-run-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$RUN_DIR"
TMPDIR="$(mktemp -d)"
HTTP_PID=""
cleanup() {
  if [[ -n "$HTTP_PID" ]] && kill -0 "$HTTP_PID" 2>/dev/null; then
    kill "$HTTP_PID" 2>/dev/null || true
    wait "$HTTP_PID" 2>/dev/null || true
  fi
  "$(dirname "$0")/stop-trusted-front-backend-candidate.sh" "$BUNDLE_DIR" > "$RUN_DIR/stop.txt" 2>&1 || true
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

PUBLIC_CERT="$BUNDLE_DIR/backend/trusted-front-server.crt"
PUBLIC_KEY="$BUNDLE_DIR/backend/trusted-front-server.key"
for path in "$PUBLIC_CERT" "$PUBLIC_KEY"; do
  if [[ ! -f "$path" ]]; then
    LATEST_BUNDLE=$(find "$(cd "$(dirname "$0")/.." && pwd)/build/staging" -maxdepth 1 -type d -name 'two-host-trusted-front-*' 2>/dev/null | sort | tail -1 || true)
    echo "bundle_dir does not look like a prepared two-host staging bundle: $BUNDLE_DIR" >&2
    echo "missing required file: $path" >&2
    echo "expected layout comes from scripts/prepare-two-host-trusted-front-staging.sh" >&2
    if [[ -n "$LATEST_BUNDLE" ]]; then
      echo "latest prepared bundle: $LATEST_BUNDLE" >&2
    fi
    exit 2
  fi
done

FALLBACK_PORT=$(python3 - <<'PY'
import socket
s=socket.socket(); s.bind(('127.0.0.1', 0)); print(s.getsockname()[1]); s.close()
PY
)

printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 23\r\nConnection: close\r\n\r\ntwo-host-local-check\n' > "$TMPDIR/fallback-response.txt"
python3 - <<'PY' "$FALLBACK_PORT" "$TMPDIR/fallback-response.txt" > "$RUN_DIR/fallback.log" 2>&1 &
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

"$(dirname "$0")/start-trusted-front-backend-candidate.sh" \
  "$BUNDLE_DIR" \
  "$TROJAN_BIN" \
  "$PUBLIC_CERT" \
  "$PUBLIC_KEY" \
  127.0.0.1 \
  "$FALLBACK_PORT" \
  "$PUBLIC_ADDR" \
  "$PUBLIC_PORT" \
  "$TRUSTED_ADDR" \
  "$TRUSTED_PORT" \
  "$PASSWORD" > "$RUN_DIR/start.txt" 2>&1

"$(dirname "$0")/run-trusted-front-front-check.sh" \
  "$BUNDLE_DIR" \
  "$TRUSTED_ADDR" \
  "$TRUSTED_PORT" \
  localhost \
  "$RUN_DIR/front-response.txt" > "$RUN_DIR/front.txt" 2>&1

cp "$BUNDLE_DIR/backend/backend-candidate.log" "$RUN_DIR/backend-candidate.log"
cp "$BUNDLE_DIR/backend/backend-candidate.runtime.json" "$RUN_DIR/backend-candidate.runtime.json"
cp "$(cd "$(dirname "$0")/.." && pwd)/docs/planning/two-host-trusted-front-first-execution-notes-template.md" "$RUN_DIR/execution-notes.md"

python3 - <<'PY' "$RUN_DIR"
from pathlib import Path
import json, sys
run = Path(sys.argv[1])
front = (run / 'front-response.txt').read_text(errors='replace') if (run / 'front-response.txt').exists() else ''
server = (run / 'backend-candidate.log').read_text(errors='replace') if (run / 'backend-candidate.log').exists() else ''
summary = {
    'front_response_present': bool(front),
    'front_response_contains_local_check': 'two-host-local-check' in front,
    'handoff_applied': 'external-front handoff applied:' in server,
    'fallback_path_seen': 'not trojan request, connecting to' in server,
    'tunnel_established': 'tunnel established' in server,
    'trusted_front_rejected': ('trusted-front connection rejected:' in server) or ('trusted-front ingress rejected:' in server),
}
(run / 'summary.json').write_text(json.dumps(summary, indent=2))
PY

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASELINE_SUMMARY="$PROJECT_ROOT/build/validation/baseline-commit-ready/summary.json"
CANDIDATE_SUMMARY="$PROJECT_ROOT/build/validation/candidate-commit-ready/summary.json"
COMPARISON_MD="$PROJECT_ROOT/build/validation/commit-ready-comparison.md"
TWO_HOST_SUMMARY="$RUN_DIR/summary.json"
VERDICT_DRAFT="$RUN_DIR/trusted-front-verdict-draft.md"
CLAIMS_PACK="$RUN_DIR/trusted-front-claims-pack.md"

if [[ -f "$BASELINE_SUMMARY" && -f "$CANDIDATE_SUMMARY" && -f "$COMPARISON_MD" ]]; then
  "$PROJECT_ROOT/scripts/generate-trusted-front-verdict.py" \
    --baseline "$BASELINE_SUMMARY" \
    --candidate "$CANDIDATE_SUMMARY" \
    --comparison "$COMPARISON_MD" \
    --two-host-summary "$TWO_HOST_SUMMARY" \
    --output "$VERDICT_DRAFT" \
    --scope "two-host local dry-run comparison" \
    --candidate-shape "trusted-front candidate with two-host dry-run support"

  "$PROJECT_ROOT/scripts/generate-trusted-front-claims-pack.py" \
    --verdict "$VERDICT_DRAFT" \
    --evidence-status "$PROJECT_ROOT/docs/trusted-front-edge-separation-evidence-status.md" \
    --rollout-checklist "$PROJECT_ROOT/docs/trusted-front-rollout-checklist.md" \
    --output "$CLAIMS_PACK"
fi

echo "completed two-host local dry run"
echo "run_dir=$RUN_DIR"
if [[ -f "$VERDICT_DRAFT" ]]; then
  echo "verdict_draft=$VERDICT_DRAFT"
fi
if [[ -f "$CLAIMS_PACK" ]]; then
  echo "claims_pack=$CLAIMS_PACK"
fi
