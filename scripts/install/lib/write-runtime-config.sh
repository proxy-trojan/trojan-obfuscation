#!/usr/bin/env bash
set -euo pipefail

phase_write_runtime_config() {
  echo "phase=write-runtime-config"

  if [[ "${INSTALL_CHECK_ONLY:-0}" == "1" ]]; then
    echo "[check-only] would write runtime config for ${INSTALL_DOMAIN}"
    return 0
  fi

  echo "write-runtime-config skeleton: real runtime config rendering is not implemented in this task"
}
