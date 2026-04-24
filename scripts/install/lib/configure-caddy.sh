#!/usr/bin/env bash
set -euo pipefail

phase_configure_caddy() {
  echo "phase=configure-caddy"

  if [[ "${INSTALL_CHECK_ONLY:-0}" == "1" ]]; then
    echo "[check-only] would render Caddy ACME config for ${INSTALL_DOMAIN} using ${INSTALL_EMAIL}"
    return 0
  fi

  echo "configure-caddy skeleton: real Caddy ACME configuration is not implemented in this task"
}
