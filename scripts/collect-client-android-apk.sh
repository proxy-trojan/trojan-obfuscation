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
APK_SOURCE="$ROOT_DIR/client/build/app/outputs/flutter-apk/app-release.apk"
ARTIFACT_DIR="$ROOT_DIR/packaging/android/artifacts/$RELEASE_DIR_NAME"
APK_NAME="${ARTIFACT_STEM}_${VERSION_LABEL}_android-release.apk"
APK_PATH="$ARTIFACT_DIR/$APK_NAME"

if [[ ! -f "$APK_SOURCE" ]]; then
  echo "missing Android APK: $APK_SOURCE" >&2
  exit 1
fi

mkdir -p "$ARTIFACT_DIR"
cp "$APK_SOURCE" "$APK_PATH"
(
  cd "$ARTIFACT_DIR"
  sha256sum "$(basename "$APK_PATH")" > "$(basename "$APK_PATH").sha256"
)

echo "collected apk: $APK_PATH"
echo "built checksum: $APK_PATH.sha256"
