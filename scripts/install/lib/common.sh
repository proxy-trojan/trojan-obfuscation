#!/usr/bin/env bash
set -euo pipefail

backup_if_exists() {
  local path="$1"
  local backup="$2"
  mkdir -p "$(dirname "$backup")"
  if [[ -e "$path" ]]; then
    cp -a "$path" "$backup"
  else
    : > "$backup.missing"
  fi
}

restore_backup() {
  local path="$1"
  local backup="$2"
  if [[ -e "$backup" ]]; then
    mkdir -p "$(dirname "$path")"
    cp -a "$backup" "$path"
  elif [[ -e "$backup.missing" ]]; then
    rm -f "$path"
  fi
}

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
