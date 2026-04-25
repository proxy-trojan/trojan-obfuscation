#!/usr/bin/env bash
set -euo pipefail

phase_install_deps() {
  echo "phase=install-deps"
  local deps=()
  case "$INSTALL_PACKAGE_MANAGER" in
    apt) deps=(curl python3 jq openssl systemd) ;;
    dnf|yum) deps=(curl python3 jq openssl systemd) ;;
    pacman) deps=(curl python jq openssl systemd) ;;
    zypper) deps=(curl python3 jq openssl systemd) ;;
  esac

  if [[ "${INSTALL_CHECK_ONLY:-0}" == "1" ]]; then
    printf '[check-only] would install dependencies: %s\n' "${deps[*]}"
    return 0
  fi

  echo "installing_dependencies=${deps[*]}"
}
