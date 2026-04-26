#!/usr/bin/env bash
set -euo pipefail

phase_cert_bootstrap() {
  echo "phase=cert-bootstrap"
  local cert_dir="${INSTALL_ROOT_PREFIX}/etc/trojan-pro/certs/current"
  mkdir -p "$cert_dir"
  if [[ "${INSTALL_CERT_BOOTSTRAP_MODE:-live}" == "fixtures" ]]; then
    cp "${INSTALL_CERT_FIXTURE_DIR}/sample_edge.crt" "$cert_dir/edge.crt"
    cp "${INSTALL_CERT_FIXTURE_DIR}/sample_edge.key" "$cert_dir/edge.key"
    echo "cert_bootstrap_mode=fixtures"
    return 0
  fi
  echo "cert_bootstrap_mode=live"
}
