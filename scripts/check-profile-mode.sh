#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 [--json] <config.json>" >&2
  exit 2
fi

JSON_MODE=0
CONFIG_PATH=""
for arg in "$@"; do
  case "$arg" in
    --json)
      JSON_MODE=1
      ;;
    *)
      if [[ -n "$CONFIG_PATH" ]]; then
        echo "unexpected extra argument: $arg" >&2
        exit 2
      fi
      CONFIG_PATH="$arg"
      ;;
  esac
done

if [[ -z "$CONFIG_PATH" ]]; then
  echo "config path is required" >&2
  exit 2
fi

python3 - <<'PY' "$CONFIG_PATH" "$JSON_MODE"
import json
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
json_mode = sys.argv[2] == '1'

if not config_path.is_file():
    print(f"config not found: {config_path}", file=sys.stderr)
    raise SystemExit(2)

try:
    config = json.loads(config_path.read_text())
except Exception as exc:
    print(f"failed to parse json: {exc}", file=sys.stderr)
    raise SystemExit(2)

external_front = config.get('external_front', {}) or {}
run_type = config.get('run_type', '')
enabled = bool(external_front.get('enabled', False))
listener_enabled = bool(external_front.get('enable_trusted_front_listener', False))
use_mtls = bool(external_front.get('trusted_front_listener_use_mtls', False))
loopback_only = bool(external_front.get('require_trusted_front_loopback_source', True))
listener_addr = external_front.get('trusted_front_listener_addr', '')
listener_port = external_front.get('trusted_front_listener_port', 0)

mode = 'invalid'
valid = False
issues = []

if run_type != 'server':
    issues.append('run_type_not_server')

if not enabled:
    mode = 'baseline'
    valid = run_type == 'server'
elif enabled and listener_enabled and use_mtls:
    mode = 'candidate'
    valid = run_type == 'server'
    if not listener_addr:
        issues.append('missing_trusted_front_listener_addr')
        valid = False
    if not listener_port:
        issues.append('missing_trusted_front_listener_port')
        valid = False
else:
    mode = 'ambiguous'
    if not listener_enabled:
        issues.append('trusted_front_listener_not_enabled')
    if not use_mtls:
        issues.append('trusted_front_listener_mtls_not_enabled')

summary = {
    'config_path': str(config_path),
    'run_type': run_type,
    'mode': mode,
    'valid': valid,
    'external_front_enabled': enabled,
    'trusted_front_listener_enabled': listener_enabled,
    'trusted_front_listener_use_mtls': use_mtls,
    'require_trusted_front_loopback_source': loopback_only,
    'trusted_front_listener_addr': listener_addr,
    'trusted_front_listener_port': listener_port,
    'issues': issues,
}

if json_mode:
    print(json.dumps(summary, indent=2, sort_keys=True))
else:
    print(f"mode={summary['mode']}")
    print(f"valid={str(summary['valid']).lower()}")
    print(f"run_type={summary['run_type']}")
    print(f"external_front_enabled={str(enabled).lower()}")
    print(f"trusted_front_listener_enabled={str(listener_enabled).lower()}")
    print(f"trusted_front_listener_use_mtls={str(use_mtls).lower()}")
    print(f"require_trusted_front_loopback_source={str(loopback_only).lower()}")
    print(f"trusted_front_listener_addr={listener_addr}")
    print(f"trusted_front_listener_port={listener_port}")
    if issues:
        print(f"issues={','.join(issues)}")
    else:
        print("issues=")

raise SystemExit(0 if valid else 1)
PY
