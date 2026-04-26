#!/usr/bin/env bash
set -euo pipefail

phase_detect_os() {
  echo "phase=detect-os"
  local os_release_path="${INSTALL_OS_RELEASE_PATH:-/etc/os-release}"

  INSTALL_OS_ID="unknown"
  INSTALL_OS_VERSION="unknown"
  if [[ -r "$os_release_path" ]]; then
    # shellcheck disable=SC1090
    . "$os_release_path"
    INSTALL_OS_ID="${ID:-unknown}"
    INSTALL_OS_VERSION="${VERSION_ID:-unknown}"
  fi

  if command -v apt-get >/dev/null 2>&1; then
    INSTALL_PACKAGE_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then
    INSTALL_PACKAGE_MANAGER="dnf"
  elif command -v yum >/dev/null 2>&1; then
    INSTALL_PACKAGE_MANAGER="yum"
  elif command -v pacman >/dev/null 2>&1; then
    INSTALL_PACKAGE_MANAGER="pacman"
  elif command -v zypper >/dev/null 2>&1; then
    INSTALL_PACKAGE_MANAGER="zypper"
  else
    echo "error: unsupported package manager" >&2
    return 1
  fi

  echo "detected_os=$INSTALL_OS_ID"
  echo "detected_version=$INSTALL_OS_VERSION"
  echo "detected_package_manager=$INSTALL_PACKAGE_MANAGER"
}
