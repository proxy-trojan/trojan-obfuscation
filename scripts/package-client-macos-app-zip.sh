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
MACOS_RELEASE_DIR="$ROOT_DIR/client/build/macos/Build/Products/Release"
ARTIFACT_DIR="$ROOT_DIR/packaging/macos/artifacts/$RELEASE_DIR_NAME"
ZIP_NAME="${ARTIFACT_STEM}_${VERSION_LABEL}_macos-app.zip"
ZIP_PATH="$ARTIFACT_DIR/$ZIP_NAME"

if [[ ! -d "$MACOS_RELEASE_DIR" ]]; then
  echo "missing macOS release directory: $MACOS_RELEASE_DIR" >&2
  exit 1
fi

APP_PATH="$(find "$MACOS_RELEASE_DIR" -maxdepth 1 -type d -name '*.app' | head -n 1)"
if [[ -z "$APP_PATH" ]]; then
  echo "no .app bundle found in: $MACOS_RELEASE_DIR" >&2
  exit 1
fi

mkdir -p "$ARTIFACT_DIR"
rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
(
  cd "$ARTIFACT_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$ZIP_PATH").sha256"
)

echo "built zip: $ZIP_PATH"
echo "built checksum: $ZIP_PATH.sha256"
