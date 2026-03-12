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

map_arch_slug() {
  case "$1" in
    amd64) echo "x64" ;;
    arm64) echo "arm64" ;;
    *) echo "$1" ;;
  esac
}

RELEASE_LABEL_DIR="v${VERSION_LABEL}"
RELEASE_BUNDLE_DIR="$ROOT_DIR/${RELEASE_BUNDLE_RELATIVE_DIR}"
ARTIFACT_OUT_DIR="$ROOT_DIR/${ARTIFACT_OUTPUT_RELATIVE_DIR}/${RELEASE_LABEL_DIR}"
LINUX_ARCH_SLUG="$(map_arch_slug "$PACKAGE_ARCH")"
TAR_PATH="$ARTIFACT_OUT_DIR/${ARTIFACT_STEM}_${VERSION_LABEL}_linux-${LINUX_ARCH_SLUG}-bundle.tar.gz"

if [[ ! -d "$RELEASE_BUNDLE_DIR" ]]; then
  echo "release bundle missing: $RELEASE_BUNDLE_DIR" >&2
  exit 1
fi

mkdir -p "$ARTIFACT_OUT_DIR"
rm -f "$TAR_PATH" "$TAR_PATH.sha256"

tar -C "$(dirname "$RELEASE_BUNDLE_DIR")" -czf "$TAR_PATH" "$(basename "$RELEASE_BUNDLE_DIR")"
(
  cd "$ARTIFACT_OUT_DIR"
  sha256sum "$(basename "$TAR_PATH")" > "$(basename "$TAR_PATH").sha256"
)

echo "built tarball: $TAR_PATH"
echo "built checksum: $TAR_PATH.sha256"
