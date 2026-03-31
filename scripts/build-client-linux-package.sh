#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT_DIR="$ROOT_DIR/client"
PACKAGING_DIR="$ROOT_DIR/packaging/linux"
TEMPLATE_DIR="$PACKAGING_DIR/deb"
ASSETS_DIR="$PACKAGING_DIR/assets"
METADATA_FILE="$PACKAGING_DIR/release-metadata.env"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

render_template() {
  local template_path="$1"
  local output_path="$2"

  python3 - "$template_path" "$output_path" <<'PY'
import os
import re
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
text = template_path.read_text()

def repl(match):
    key = match.group(1)
    try:
        return os.environ[key]
    except KeyError:
        raise SystemExit(f"missing template variable: {key}")

rendered = re.sub(r'@([A-Z0-9_]+)@', repl, text)
output_path.write_text(rendered)
PY
}

need_cmd flutter
need_cmd dpkg-deb
need_cmd python3

if [[ ! -f "$METADATA_FILE" ]]; then
  echo "missing release metadata: $METADATA_FILE" >&2
  exit 1
fi

# Export metadata variables so template rendering subprocesses can read them.
set -a
# shellcheck disable=SC1090
source "$METADATA_FILE"
set +a

if [[ $# -ge 1 && -n "${1:-}" ]]; then
  VERSION_LABEL="$1"
fi
if [[ $# -ge 2 && -n "${2:-}" ]]; then
  DEB_VERSION="$2"
fi

export VERSION_LABEL DEB_VERSION

RELEASE_LABEL_DIR="v${VERSION_LABEL}"
RELEASE_BUNDLE_DIR="$ROOT_DIR/${RELEASE_BUNDLE_RELATIVE_DIR}"
ARTIFACT_OUT_DIR="$ROOT_DIR/${ARTIFACT_OUTPUT_RELATIVE_DIR}/${RELEASE_LABEL_DIR}"
STAGING_ROOT_DIR="$ROOT_DIR/${STAGING_RELATIVE_DIR}"
PACKAGE_STAGING_DIR="$STAGING_ROOT_DIR/${PACKAGE_NAME}_${DEB_VERSION}_${PACKAGE_ARCH}"
INSTALL_APP_DIR="$PACKAGE_STAGING_DIR${INSTALL_PREFIX}"
DESKTOP_ENTRY_TARGET="$PACKAGE_STAGING_DIR/usr/share/applications/${DESKTOP_FILE_ID}"
ICON_TARGET_DIR="$PACKAGE_STAGING_DIR/usr/share/icons/hicolor/256x256/apps"
DEB_FILENAME_VERSION="$VERSION_LABEL"
DEB_PATH="$ARTIFACT_OUT_DIR/${ARTIFACT_STEM}_${DEB_FILENAME_VERSION}_${PACKAGE_ARCH}.deb"

mkdir -p "$ARTIFACT_OUT_DIR" "$STAGING_ROOT_DIR" "$TEMPLATE_DIR" "$ASSETS_DIR"

cd "$CLIENT_DIR"

if [[ ! -d "$CLIENT_DIR/linux" ]]; then
  echo "linux desktop scaffolding missing; run: flutter create . --platforms=linux" >&2
  exit 1
fi

if [[ ! -d "$RELEASE_BUNDLE_DIR" || ! -f "$RELEASE_BUNDLE_DIR/$EXECUTABLE_NAME" ]]; then
  echo "release bundle missing or incomplete; building linux release bundle first"
  flutter pub get
  flutter analyze
  flutter build linux --release
else
  echo "reusing existing linux release bundle: $RELEASE_BUNDLE_DIR"
fi

if [[ ! -d "$RELEASE_BUNDLE_DIR" ]]; then
  echo "release bundle missing: $RELEASE_BUNDLE_DIR" >&2
  exit 1
fi

if [[ ! -f "$RELEASE_BUNDLE_DIR/$EXECUTABLE_NAME" ]]; then
  echo "expected executable missing from release bundle: $RELEASE_BUNDLE_DIR/$EXECUTABLE_NAME" >&2
  echo "fix the Linux scaffold/binary naming before packaging" >&2
  exit 1
fi

rm -rf "$PACKAGE_STAGING_DIR"
mkdir -p "$PACKAGE_STAGING_DIR/DEBIAN"
mkdir -p "$INSTALL_APP_DIR"
mkdir -p "$(dirname "$DESKTOP_ENTRY_TARGET")"

cp -R "$RELEASE_BUNDLE_DIR"/. "$INSTALL_APP_DIR/"

render_template "$TEMPLATE_DIR/control.in" "$PACKAGE_STAGING_DIR/DEBIAN/control"
render_template "$TEMPLATE_DIR/trojan-pro-client.desktop.in" "$DESKTOP_ENTRY_TARGET"
chmod 0644 "$PACKAGE_STAGING_DIR/DEBIAN/control" "$DESKTOP_ENTRY_TARGET"

if [[ -f "$ROOT_DIR/$ICON_SOURCE" ]]; then
  mkdir -p "$ICON_TARGET_DIR"
  cp "$ROOT_DIR/$ICON_SOURCE" "$ICON_TARGET_DIR/${ICON_NAME}.png"
fi

rm -f "$DEB_PATH" "$DEB_PATH.sha256"
dpkg-deb --build "$PACKAGE_STAGING_DIR" "$DEB_PATH"
(
  cd "$ARTIFACT_OUT_DIR"
  sha256sum "$(basename "$DEB_PATH")" > "$(basename "$DEB_PATH").sha256"
)

echo "built package: $DEB_PATH"
echo "built checksum: $DEB_PATH.sha256"
echo "version label: $VERSION_LABEL"
echo "deb version: $DEB_VERSION"
echo "deb filename version: $DEB_FILENAME_VERSION"
echo "staging dir: $PACKAGE_STAGING_DIR"
