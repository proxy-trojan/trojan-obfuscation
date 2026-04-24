#!/usr/bin/env bash
set -euo pipefail

phase_install_core() {
  echo "phase=install-core"

  if [[ "${INSTALL_CHECK_ONLY:-0}" == "1" ]]; then
    echo "[check-only] would install trojan core"
    return 0
  fi

  echo "install-core skeleton: real core installation is not implemented in this task"
}
