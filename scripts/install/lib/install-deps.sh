#!/usr/bin/env bash
set -euo pipefail

phase_install_deps() {
  echo "phase=install-deps"

  if [[ "${INSTALL_CHECK_ONLY:-0}" == "1" ]]; then
    echo "[check-only] would install dependencies for detected Linux distro"
    return 0
  fi

  echo "install-deps skeleton: real dependency installation is not implemented in this task"
}
