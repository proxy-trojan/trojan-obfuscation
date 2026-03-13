#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_ROOT="${1:-artifacts}"

if [[ ! -d "$ARTIFACT_ROOT" ]]; then
  echo "artifact root does not exist: $ARTIFACT_ROOT" >&2
  exit 1
fi

checksum_cmd() {
  if command -v sha256sum >/dev/null 2>&1; then
    echo "sha256sum"
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    echo "shasum"
    return
  fi
  echo "missing checksum tool: need sha256sum or shasum" >&2
  exit 1
}

VERIFY_TOOL="$(checksum_cmd)"
CHECKSUM_FILES=()
while IFS= read -r f; do
  CHECKSUM_FILES+=("$f")
done < <(find "$ARTIFACT_ROOT" -type f -name '*.sha256' | sort)

if [[ ${#CHECKSUM_FILES[@]} -eq 0 ]]; then
  echo "no .sha256 files found under: $ARTIFACT_ROOT" >&2
  exit 1
fi

verified=0
for checksum_file in "${CHECKSUM_FILES[@]}"; do
  checksum_dir="$(dirname "$checksum_file")"
  checksum_name="$(basename "$checksum_file")"
  echo "==> verifying checksum: $checksum_file"
  (
    cd "$checksum_dir"
    if [[ "$VERIFY_TOOL" == "sha256sum" ]]; then
      sha256sum -c "$checksum_name"
    else
      shasum -a 256 -c "$checksum_name"
    fi
  )
  verified=$((verified + 1))
done

echo
echo "checksum verification summary"
echo "- artifact root: $ARTIFACT_ROOT"
echo "- checksum files verified: $verified"
echo "- verification tool: $VERIFY_TOOL"
