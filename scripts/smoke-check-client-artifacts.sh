#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_ROOT="${1:-artifacts}"
PLATFORMS="linux,windows,macos"
EXPECT_ANDROID="false"
SMOKE_WINDOW_SECONDS="${SMOKE_WINDOW_SECONDS:-8}"

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platforms)
      PLATFORMS="$2"
      shift 2
      ;;
    --expect-android)
      EXPECT_ANDROID="true"
      shift
      ;;
    --no-expect-android)
      EXPECT_ANDROID="false"
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$ARTIFACT_ROOT" ]]; then
  echo "artifact root does not exist: $ARTIFACT_ROOT" >&2
  exit 1
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

need_cmd find
need_cmd sort
need_cmd head
need_cmd grep
need_cmd unzip
need_cmd mktemp

find_one() {
  local pattern="$1"
  find "$ARTIFACT_ROOT" -type f -name "$pattern" | sort | head -n 1
}

contains_platform() {
  local wanted="$1"
  local item
  IFS=',' read -r -a items <<< "$PLATFORMS"
  for item in "${items[@]}"; do
    if [[ "$item" == "$wanted" ]]; then
      return 0
    fi
  done
  return 1
}

launch_linux_smoke() {
  local executable="$1"
  local log_path="$2"

  if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    set +e
    timeout "${SMOKE_WINDOW_SECONDS}s" "$executable" >"$log_path" 2>&1
    local rc=$?
    set -e
    [[ $rc -eq 124 ]]
    return
  fi

  if command -v xvfb-run >/dev/null 2>&1; then
    set +e
    timeout "${SMOKE_WINDOW_SECONDS}s" xvfb-run -a "$executable" >"$log_path" 2>&1
    local rc=$?
    set -e
    [[ $rc -eq 124 ]]
    return
  fi

  return 125
}

SMOKE_TMPDIR="$(mktemp -d)"
cleanup() {
  rm -rf "$SMOKE_TMPDIR"
}
trap cleanup EXIT

linux_install_ok="skipped"
linux_start_ok="skipped"
windows_ok="skipped"
macos_ok="skipped"
android_ok="skipped"

if contains_platform linux; then
  need_cmd tar
  need_cmd timeout
  need_cmd dpkg-deb
  deb_file="$(find_one 'trojan-pro-client_*_amd64.deb')"
  tar_file="$(find_one 'trojan-pro-client_*_linux-x64-bundle.tar.gz')"

  if [[ -z "$deb_file" || -z "$tar_file" ]]; then
    echo "linux artifacts missing under $ARTIFACT_ROOT" >&2
    exit 1
  fi

  echo "==> linux install smoke: $deb_file"
  dpkg-deb -I "$deb_file" >/dev/null
  dpkg-deb -x "$deb_file" "$SMOKE_TMPDIR/linux-deb"

  deb_executable="$SMOKE_TMPDIR/linux-deb/opt/trojan-pro-client/trojan_pro_client"
  if [[ ! -f "$deb_executable" ]]; then
    echo "expected executable missing after deb extraction: $deb_executable" >&2
    exit 1
  fi
  linux_install_ok="passed"

  echo "==> linux bundle smoke: $tar_file"
  mkdir -p "$SMOKE_TMPDIR/linux-bundle"
  tar -C "$SMOKE_TMPDIR/linux-bundle" -xzf "$tar_file"
  bundle_executable="$(find "$SMOKE_TMPDIR/linux-bundle" -type f -name 'trojan_pro_client' | head -n 1)"
  if [[ -z "$bundle_executable" ]]; then
    echo "expected bundle executable missing after tar extraction" >&2
    exit 1
  fi

  log_path="$SMOKE_TMPDIR/linux-bundle-start.log"
  if launch_linux_smoke "$bundle_executable" "$log_path"; then
    linux_start_ok="passed"
  else
    rc=$?
    if [[ $rc -eq 125 ]]; then
      linux_start_ok="skipped (no DISPLAY / WAYLAND_DISPLAY and xvfb-run unavailable)"
    else
      echo "linux bundle start smoke failed; log follows:" >&2
      sed -n '1,160p' "$log_path" >&2 || true
      exit 1
    fi
  fi
fi

if contains_platform windows; then
  windows_zip="$(find_one 'trojan-pro-client_*_windows-x64.zip')"
  if [[ -z "$windows_zip" ]]; then
    echo "windows artifact missing under $ARTIFACT_ROOT" >&2
    exit 1
  fi

  echo "==> windows zip smoke: $windows_zip"
  unzip -l "$windows_zip" | grep -E '\.exe$' >/dev/null
  windows_ok="passed"
fi

if contains_platform macos; then
  macos_zip="$(find_one 'trojan-pro-client_*_macos-app.zip')"
  if [[ -z "$macos_zip" ]]; then
    echo "macOS artifact missing under $ARTIFACT_ROOT" >&2
    exit 1
  fi

  echo "==> macOS zip smoke: $macos_zip"
  unzip -l "$macos_zip" | grep -E '\.app/' >/dev/null
  unzip -l "$macos_zip" | grep -E '\.app/Contents/MacOS/' >/dev/null
  macos_ok="passed"
fi

if [[ "$EXPECT_ANDROID" == "true" ]]; then
  android_apk="$(find_one 'trojan-pro-client_*_android-release.apk')"
  if [[ -z "$android_apk" ]]; then
    echo "android artifact missing under $ARTIFACT_ROOT" >&2
    exit 1
  fi

  echo "==> android apk smoke: $android_apk"
  unzip -l "$android_apk" | grep -E 'AndroidManifest\.xml' >/dev/null
  android_ok="passed"
fi

echo
echo "client artifact smoke summary"
echo "- artifact root: $ARTIFACT_ROOT"
echo "- requested platforms: $PLATFORMS"
echo "- linux install smoke: $linux_install_ok"
echo "- linux start smoke: $linux_start_ok"
echo "- windows zip smoke: $windows_ok"
echo "- macOS app zip smoke: $macos_ok"
if [[ "$EXPECT_ANDROID" == "true" ]]; then
  echo "- android apk smoke: $android_ok"
fi
