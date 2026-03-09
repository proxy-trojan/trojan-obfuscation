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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
SERVER_CONFIG="$REPO_ROOT/examples/server.json-example"

if [[ ! -f "$SERVER_CONFIG" ]]; then
  echo "missing server example config: $SERVER_CONFIG" >&2
  exit 2
fi

set +e
OUTPUT="$($TROJAN_BIN -t -c "$SERVER_CONFIG" 2>&1)"
STATUS=$?
set -e

if [[ $STATUS -eq 0 ]]; then
  echo "expected server example config test to fail because certificate paths are placeholders" >&2
  exit 1
fi

if [[ "$OUTPUT" != *"certificate"* && "$OUTPUT" != *"private.key"* && "$OUTPUT" != *"No such file"* ]]; then
  echo "unexpected failure output:" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

echo "LinuxSmokeTest-server-config-fails: ok"
