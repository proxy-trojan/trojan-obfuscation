#!/usr/bin/env bash
set -euo pipefail

phase_write_runtime_config() {
  echo "phase=write-runtime-config"

  if [[ "${INSTALL_CHECK_ONLY:-0}" == "1" ]]; then
    echo "[check-only] would write runtime config for ${INSTALL_EDGE_DOMAIN}"
    return 0
  fi

  local manifest_path="${INSTALL_ROOT_PREFIX}/etc/trojan-pro/install-manifest.json"
  local config_path="${INSTALL_ROOT_PREFIX}/etc/trojan-pro/config.json"
  mkdir -p "$(dirname "$manifest_path")"

  python3 - <<'PY' "$INSTALL_ROOT_PREFIX" "$INSTALL_WWW_DOMAIN" "$INSTALL_EDGE_DOMAIN" "$INSTALL_DNS_PROVIDER" "$INSTALL_TROJAN_LOCAL_PORT"
import sys
from pathlib import Path

repo_root = Path.cwd()
if str(repo_root) not in sys.path:
    sys.path.insert(0, str(repo_root))

from scripts.install.runtime.manifest import write_manifest
from scripts.install.runtime.provider_registry import load_provider_registry
from scripts.install.runtime.render_runtime import render_trojan_config

root_prefix = Path(sys.argv[1])
www_domain = sys.argv[2]
edge_domain = sys.argv[3]
dns_provider = sys.argv[4]
trojan_local_port = int(sys.argv[5])
registry = load_provider_registry()
manifest = {
    "www_domain": www_domain,
    "edge_domain": edge_domain,
    "dns_provider": dns_provider,
    "dns_provider_module": registry[dns_provider].caddy_dns_module,
    "support_tier": registry[dns_provider].support_tier,
    "web_mode": "static",
    "trojan_local_addr": "127.0.0.1",
    "trojan_local_port": trojan_local_port,
    "trojan_password_env_key": "TROJAN_PASSWORD",
}
write_manifest(root_prefix, manifest)
config_path = root_prefix / 'etc' / 'trojan-pro' / 'config.json'
config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text(render_trojan_config(manifest), encoding='utf-8')
PY
}
