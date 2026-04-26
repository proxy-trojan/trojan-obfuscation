#!/usr/bin/env bash
set -euo pipefail

install_binary_from_lock() {
  local lock_path="$1"
  local asset_name="$2"
  local target_key="$3"
  local dest="$4"
  local tmp
  tmp="$(mktemp)"

  mapfile -t meta < <(python3 - <<'PY' "$lock_path" "$asset_name" "$target_key"
import json
import os
import sys

with open(sys.argv[1], encoding='utf-8') as handle:
    payload = json.load(handle)
entry = payload[sys.argv[2]][sys.argv[3]]
overrides = {
    ('trojan', 'url'): os.environ.get('TEST_TROJAN_BIN_URL'),
    ('trojan', 'sha256'): os.environ.get('TEST_TROJAN_BIN_SHA256'),
    ('caddy-custom', 'url'): os.environ.get('TEST_CADDY_BIN_URL'),
    ('caddy-custom', 'sha256'): os.environ.get('TEST_CADDY_BIN_SHA256'),
}
url = overrides.get((sys.argv[2], 'url')) or entry['url']
sha256 = overrides.get((sys.argv[2], 'sha256')) or entry['sha256']
print(url)
print(sha256)
print(entry['version'])
PY
)

  python3 - <<'PY' "$tmp" "${meta[0]}"
import pathlib
import shutil
import sys
import urllib.parse

src = urllib.parse.urlparse(sys.argv[2])
if src.scheme != 'file':
    raise SystemExit('only file:// is allowed in contract tests')
shutil.copyfile(pathlib.Path(src.path), pathlib.Path(sys.argv[1]))
PY

  [[ "$(sha256_file "$tmp")" == "${meta[1]}" ]]
  atomic_install_executable "$tmp" "$dest"
  rm -f "$tmp"
  printf 'installed_asset=%s\ninstalled_version=%s\n' "$asset_name" "${meta[2]}"
}
