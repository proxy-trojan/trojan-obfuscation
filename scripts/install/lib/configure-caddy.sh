#!/usr/bin/env bash
set -euo pipefail

phase_configure_caddy() {
  echo "phase=configure-caddy"

  if [[ "${INSTALL_CHECK_ONLY:-0}" == "1" ]]; then
    echo "[check-only] would render Caddy ACME config for ${INSTALL_WWW_DOMAIN} and edge ${INSTALL_EDGE_DOMAIN} via ${INSTALL_DNS_PROVIDER}"
    return 0
  fi

  local caddyfile_path="${INSTALL_ROOT_PREFIX}/etc/caddy/Caddyfile"
  mkdir -p "$(dirname "$caddyfile_path")"

  python3 - <<'PY' "$INSTALL_ROOT_PREFIX"
import sys
from pathlib import Path

repo_root = Path.cwd()
if str(repo_root) not in sys.path:
    sys.path.insert(0, str(repo_root))

from scripts.install.runtime.manifest import read_manifest
from scripts.install.runtime.render_runtime import render_caddyfile

root_prefix = Path(sys.argv[1])
manifest = read_manifest(root_prefix)
caddyfile_path = root_prefix / 'etc' / 'caddy' / 'Caddyfile'
caddyfile_path.parent.mkdir(parents=True, exist_ok=True)
caddyfile_path.write_text(render_caddyfile(manifest), encoding='utf-8')
PY
}
