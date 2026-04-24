#!/usr/bin/env bash
set -euo pipefail

phase_detect_os() {
  echo "phase=detect-os"

  local os_id="unknown"
  local os_version="unknown"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    os_id="${ID:-unknown}"
    os_version="${VERSION_ID:-unknown}"
  fi

  echo "detected_os=$os_id"
  echo "detected_version=$os_version"
}
