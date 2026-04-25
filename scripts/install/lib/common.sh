#!/usr/bin/env bash
set -euo pipefail

sha256_file() {
  local path="$1"
  sha256sum "$path" | awk '{print $1}'
}

atomic_install_executable() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  install -m 0755 "$src" "$dest.tmp"
  mv "$dest.tmp" "$dest"
}
