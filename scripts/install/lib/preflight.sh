#!/usr/bin/env bash
set -euo pipefail

phase_preflight() {
  echo "phase=preflight"
  local env_errors
  env_errors="$(python3 - <<'PY' "$INSTALL_DNS_PROVIDER" "$INSTALL_ENV_FILE" "$0"
from pathlib import Path
import os
import sys

script_path = Path(sys.argv[3]).resolve()
repo_root = script_path.parents[2]
if str(repo_root) not in sys.path:
    sys.path.insert(0, str(repo_root))

from scripts.install.runtime.manifest import load_env_file
from scripts.install.runtime.provider_registry import validate_provider_env

root = Path(sys.argv[2]).parents[2] if sys.argv[2] else Path('/')
env = load_env_file(root)
for key, value in os.environ.items():
    if value:
        env.setdefault(key, value)
print('\n'.join(validate_provider_env(sys.argv[1], env)))
PY
)"
  if [[ -n "$env_errors" ]]; then
    while IFS= read -r item; do
      [[ -n "$item" ]] && echo "missing_provider_env=$item" >&2
    done <<< "$env_errors"
    return 1
  fi
}
