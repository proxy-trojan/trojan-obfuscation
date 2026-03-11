#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <bundle_dir>" >&2
  exit 2
fi

BUNDLE_DIR="$1"
PID_FILE="$BUNDLE_DIR/backend/backend-candidate.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "no pid file found: $PID_FILE" >&2
  exit 1
fi

PID=$(cat "$PID_FILE")
if [[ -z "$PID" ]]; then
  echo "empty pid file: $PID_FILE" >&2
  exit 1
fi

if kill -0 "$PID" 2>/dev/null; then
  kill "$PID"
  wait "$PID" 2>/dev/null || true
fi

rm -f "$PID_FILE"
echo "stopped trusted-front backend candidate"
