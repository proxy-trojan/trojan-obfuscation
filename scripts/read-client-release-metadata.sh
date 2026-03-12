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

linux_arch_slug() {
  case "$1" in
    amd64) echo "x64" ;;
    arm64) echo "arm64" ;;
    *) echo "$1" ;;
  esac
}

emit_kv() {
  printf '%s=%s\n' "$1" "$2"
}

if [[ "${1:-}" == "--github-output" ]]; then
  : "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required for --github-output}"
  {
    emit_kv version_label "$VERSION_LABEL"
    emit_kv deb_version "$DEB_VERSION"
    emit_kv artifact_stem "$ARTIFACT_STEM"
    emit_kv package_arch "$PACKAGE_ARCH"
    emit_kv linux_arch_slug "$(linux_arch_slug "$PACKAGE_ARCH")"
    emit_kv release_dir_name "v$VERSION_LABEL"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

emit_kv VERSION_LABEL "$VERSION_LABEL"
emit_kv DEB_VERSION "$DEB_VERSION"
emit_kv ARTIFACT_STEM "$ARTIFACT_STEM"
emit_kv PACKAGE_ARCH "$PACKAGE_ARCH"
emit_kv LINUX_ARCH_SLUG "$(linux_arch_slug "$PACKAGE_ARCH")"
emit_kv RELEASE_DIR_NAME "v$VERSION_LABEL"
