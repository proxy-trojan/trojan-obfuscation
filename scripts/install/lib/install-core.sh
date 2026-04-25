#!/usr/bin/env bash
set -euo pipefail

phase_install_core() {
  echo "phase=install-core"

  if [[ "${INSTALL_CHECK_ONLY:-0}" == "1" ]]; then
    echo "[check-only] would install trojan core and custom caddy"
    return 0
  fi

  install_binary_from_lock "$INSTALL_BINARIES_LOCK" trojan "$INSTALL_TARGET_KEY" "$INSTALL_TROJAN_BIN"
  install_binary_from_lock "$INSTALL_BINARIES_LOCK" caddy-custom "$INSTALL_TARGET_KEY" "$INSTALL_CADDY_BIN"
}
