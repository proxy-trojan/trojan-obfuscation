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
CLIENT_CONFIG="$REPO_ROOT/examples/client.json-example"

if [[ ! -f "$CLIENT_CONFIG" ]]; then
  echo "missing client example config: $CLIENT_CONFIG" >&2
  exit 2
fi

"$TROJAN_BIN" -h >/dev/null
"$TROJAN_BIN" -v >/dev/null
"$TROJAN_BIN" -t -c "$CLIENT_CONFIG" >/dev/null

echo "LinuxSmokeTest-basic: ok"
