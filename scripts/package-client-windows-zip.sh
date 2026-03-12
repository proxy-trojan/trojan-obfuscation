#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
METADATA_FILE="$ROOT_DIR/packaging/linux/release-metadata.env"

if [[ ! -f "$METADATA_FILE" ]]; then
  echo "missing release metadata: $METADATA_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$METADATA_FILE"

if [[ $# -ge 1 && -n "${1:-}" ]]; then
  VERSION_LABEL="$1"
fi

RELEASE_DIR_NAME="v${VERSION_LABEL}"
WINDOWS_RELEASE_DIR="$ROOT_DIR/client/build/windows/x64/runner/Release"
ARTIFACT_DIR="$ROOT_DIR/packaging/windows/artifacts/$RELEASE_DIR_NAME"
ZIP_NAME="${ARTIFACT_STEM}_${VERSION_LABEL}_windows-x64.zip"
ZIP_PATH="$ARTIFACT_DIR/$ZIP_NAME"

if [[ ! -d "$WINDOWS_RELEASE_DIR" ]]; then
  echo "missing Windows release directory: $WINDOWS_RELEASE_DIR" >&2
  exit 1
fi

mkdir -p "$ARTIFACT_DIR"
rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"

if command -v 7z >/dev/null 2>&1; then
  (
    cd "$WINDOWS_RELEASE_DIR"
    7z a "$ZIP_PATH" .
  )
else
  powershell.exe -NoProfile -Command \
    "Compress-Archive -Path '$WINDOWS_RELEASE_DIR\\*' -DestinationPath '$ZIP_PATH' -Force"
fi

(
  cd "$ARTIFACT_DIR"
  sha256sum "$(basename "$ZIP_PATH")" > "$(basename "$ZIP_PATH").sha256"
)

echo "built zip: $ZIP_PATH"
echo "built checksum: $ZIP_PATH.sha256"
