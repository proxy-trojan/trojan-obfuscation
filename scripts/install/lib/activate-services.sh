#!/usr/bin/env bash
set -euo pipefail

phase_activate_services() {
  echo "phase=activate-services"
  systemctl daemon-reload
  systemctl restart caddy-custom.service
  systemctl restart trojan-pro.service
}

phase_validate() {
  echo "phase=validate"
  if [[ "${INSTALL_FORCE_VALIDATE_FAIL:-0}" == "1" ]]; then
    echo "forced_validate_failure=1" >&2
    return 1
  fi
  test -s "${INSTALL_ROOT_PREFIX}/etc/trojan-pro/config.json"
  test -s "${INSTALL_ROOT_PREFIX}/etc/caddy/Caddyfile"
  test -s "${INSTALL_ROOT_PREFIX}/etc/trojan-pro/certs/current/edge.crt"
}
