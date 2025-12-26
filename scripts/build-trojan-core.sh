#!/usr/bin/env bash
#
# build-trojan-core.sh
#
# Cross-platform build script for trojan core.
# Policy: Scheme B - only checks dependencies; does NOT auto-install.
#
# Output:
#   trojan-pro/dist/
#     trojan-<version>-<os>-<arch>
#     trojan            (convenience copy of the latest build)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Detect host OS/arch once at startup
readonly HOST_UNAME_S="$(uname -s)"
readonly HOST_UNAME_M="$(uname -m)"

# Normalize host OS
case "$HOST_UNAME_S" in
  Darwin) readonly HOST_OS="macos" ;;
  Linux)  readonly HOST_OS="linux" ;;
  MINGW*|MSYS*|CYGWIN*) readonly HOST_OS="windows" ;;
  *) readonly HOST_OS="unknown" ;;
esac

# Normalize host architecture
case "$HOST_UNAME_M" in
  x86_64|amd64) readonly HOST_ARCH="x86_64" ;;
  arm64|aarch64) readonly HOST_ARCH="arm64" ;;
  armv7l|armv7) readonly HOST_ARCH="armv7" ;;
  *) readonly HOST_ARCH="$HOST_UNAME_M" ;;
esac

BUILD_TYPE="Release"
CLEAN=0
STRIP_BIN=1
TARGET_OS=""
TARGET_ARCH=""
BUILD_ALL=0
BUILD_MOBILE=0

usage() {
    echo "Usage: scripts/build-trojan-core.sh [options]

  Options:
    --build-type <Release|Debug|RelWithDebInfo|MinSizeRel>
    --target-os <linux|macos|windows|android|ios>  Target OS (default: auto-detect)
    --target-arch <x86_64|arm64|armv7>             Target architecture (default: auto-detect)
    --build-all                                    Build for all desktop platforms:
                                                     - Linux: x86_64, arm64
                                                     - macOS: x86_64, arm64
                                                     - Windows: x86_64, arm64
    --build-mobile                                 Build for all mobile platforms:
                                                     - Android: arm64-v8a, armeabi-v7a
                                                     - iOS: arm64
    --clean                                        Remove the build directory before building
    --no-strip                                     Do not strip the output binary
    -h, --help                                     Show help

  Examples:
    # Native build (current platform)
    ./scripts/build-trojan-core.sh
  
    # Cross-compile for Linux ARM64
    ./scripts/build-trojan-core.sh --target-os linux --target-arch arm64
  
    # Build all desktop platforms
    ./scripts/build-trojan-core.sh --build-all
  
    # Build all mobile platforms
    ./scripts/build-trojan-core.sh --build-mobile
  
    # Cross-compile for Android ARM64
    ./scripts/build-trojan-core.sh --target-os android --target-arch arm64"
  }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-type)
      BUILD_TYPE="${2:-}"; shift 2 ;;
    --target-os)
      TARGET_OS="${2:-}"; shift 2 ;;
    --target-arch)
      TARGET_ARCH="${2:-}"; shift 2 ;;
    --build-all)
      BUILD_ALL=1; shift ;;
    --build-mobile)
      BUILD_MOBILE=1; shift ;;
    --clean)
      CLEAN=1; shift ;;
    --no-strip)
      STRIP_BIN=0; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "$PROJECT_ROOT"

# Helper function for batch builds
build_platforms() {
  local label="$1"
  shift
  local platforms=("$@")

  echo "Building for all $label platforms..."
  echo ""

  local this_script="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
  local extra_args=()
  [[ $CLEAN -eq 1 ]] && extra_args+=("--clean")
  [[ $STRIP_BIN -eq 0 ]] && extra_args+=("--no-strip")

  for platform in "${platforms[@]}"; do
    local os="${platform%%:*}"
    local arch="${platform##*:}"
    echo "======================================================"
    echo "Building: $os / $arch"
    echo "======================================================"
    "$this_script" --target-os "$os" --target-arch "$arch" --build-type "$BUILD_TYPE" ${extra_args[@]+"${extra_args[@]}"} || echo "Warning: $os/$arch build failed, continuing..."
    echo ""
  done

  echo "======================================================"
  echo "$label builds completed!"
  echo "======================================================"
  ls -lh "$PROJECT_ROOT/dist/" 2>/dev/null || true
}

# --- Handle --build-all flag (desktop platforms) ---
if [[ $BUILD_ALL -eq 1 ]]; then
  build_platforms "Desktop" "linux:x86_64" "linux:arm64" "macos:x86_64" "macos:arm64" "windows:x86_64" "windows:arm64"
  exit 0
fi

# --- Handle --build-mobile flag ---
if [[ $BUILD_MOBILE -eq 1 ]]; then
  build_platforms "Mobile" "android:arm64" "android:armv7" "ios:arm64"
  exit 0
fi

# --- Detect or use specified OS/arch ---
if [[ -n "$TARGET_OS" ]]; then
  OS_ID="$TARGET_OS"
else
  OS_ID="$HOST_OS"
fi

if [[ -n "$TARGET_ARCH" ]]; then
  ARCH_ID="$TARGET_ARCH"
else
  ARCH_ID="$HOST_ARCH"
fi

# Validate OS/arch
case "$OS_ID" in
  linux|macos|windows|android|ios) ;;
  *)
    echo "Error: Unsupported or unknown OS: $OS_ID" >&2
    echo "Supported: linux, macos, windows, android, ios" >&2
    exit 1
    ;;
esac

case "$ARCH_ID" in
  x86_64|arm64|armv7) ;;
  *)
    echo "Warning: Uncommon architecture: $ARCH_ID" >&2
    ;;
esac

# --- Dependency checks (Scheme B) ---
install_hint() {
  local cmd="$1"
  local hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Missing dependency: $cmd" >&2
    echo "Install: $hint" >&2
    exit 1
  fi
}

# Check core build tools (reuse HOST_OS detected at startup)
if [[ "$HOST_OS" == "macos" ]]; then
  install_hint cmake "brew install cmake"
  install_hint make "xcode-select --install"
else
  install_hint cmake "apt install cmake (Debian/Ubuntu) or yum install cmake (RHEL/CentOS)"
  install_hint make "apt install build-essential (Debian/Ubuntu) or yum groupinstall 'Development Tools' (RHEL/CentOS)"
fi

# Check C++ compiler
if ! command -v c++ >/dev/null 2>&1; then
  echo "Error: Missing dependency: C++ compiler (c++)" >&2
  if [[ "$HOST_OS" == "macos" ]]; then
    echo "Install: xcode-select --install" >&2
  else
    echo "Install: apt install build-essential (Debian/Ubuntu) or yum groupinstall 'Development Tools' (RHEL/CentOS)" >&2
  fi
  exit 1
fi

# Job count (use HOST_OS since we run build on host machine)
if command -v nproc >/dev/null 2>&1; then
  JOBS="$(nproc)"
elif [[ "$HOST_OS" == "macos" ]]; then
  JOBS="$(sysctl -n hw.ncpu)"
else
  JOBS=4
fi

# Version (prefer git describe)
VERSION=""
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  VERSION="$(git describe --tags --always --dirty 2>/dev/null || true)"
fi
if [[ -z "$VERSION" ]]; then
  VERSION="$(date +%Y%m%d%H%M%S)"
fi

BUILD_DIR="$PROJECT_ROOT/build/${OS_ID}-${ARCH_ID}-${BUILD_TYPE}"
DIST_DIR="$PROJECT_ROOT/dist"

if [[ $CLEAN -eq 1 ]]; then
  rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR" "$DIST_DIR"

# --- Detect cross-compilation (reuse HOST_OS/HOST_ARCH from startup) ---
IS_CROSS_COMPILE=0
if [[ "$OS_ID" != "$HOST_OS" ]] || [[ "$ARCH_ID" != "$HOST_ARCH" ]]; then
  IS_CROSS_COMPILE=1
  echo "Cross-compiling: $HOST_OS/$HOST_ARCH -> $OS_ID/$ARCH_ID"
fi

# --- Platform-specific hints ---
CMAKE_EXTRA_ARGS=()

# Cross-compilation for Linux targets
if [[ $IS_CROSS_COMPILE -eq 1 ]] && [[ "$OS_ID" == "linux" ]]; then
  echo "Note: Cross-compiling to Linux from $HOST_OS" >&2
  echo "This requires appropriate cross-compilation toolchain installed." >&2
  echo "If build fails, consider building natively on a Linux machine." >&2
  # Continue to native CMake build - user is responsible for toolchain setup
fi

# Cross-compilation for macOS targets
if [[ $IS_CROSS_COMPILE -eq 1 ]] && [[ "$OS_ID" == "macos" ]]; then
  if [[ "$HOST_OS" != "macos" ]]; then
    echo "Error: Cross-compiling to macOS from non-macOS hosts requires osxcross toolchain" >&2
    echo "This is complex to set up. Consider building natively on macOS or using CI." >&2
    exit 1
  fi
  
  # macOS native cross-arch build (e.g., x86_64 -> arm64 or vice versa)
  case "$ARCH_ID" in
    x86_64)
      CMAKE_EXTRA_ARGS+=("-DCMAKE_OSX_ARCHITECTURES=x86_64")
      ;;
    arm64)
      CMAKE_EXTRA_ARGS+=("-DCMAKE_OSX_ARCHITECTURES=arm64")
      ;;
  esac
fi

# Cross-compilation for Windows targets
if [[ $IS_CROSS_COMPILE -eq 1 ]] && [[ "$OS_ID" == "windows" ]]; then
  case "$ARCH_ID" in
    x86_64)
      MINGW_PREFIX="x86_64-w64-mingw32"
      ;;
    arm64)
      MINGW_PREFIX="aarch64-w64-mingw32"
      ;;
    *)
      echo "Error: Unsupported Windows architecture: $ARCH_ID" >&2
      exit 1
      ;;
  esac
  
  if ! command -v "${MINGW_PREFIX}-gcc" >/dev/null 2>&1; then
    echo "Warning: mingw-w64 toolchain not found: ${MINGW_PREFIX}-gcc" >&2
    echo "Install: brew install mingw-w64 (macOS) or apt install mingw-w64 (Linux)" >&2
    echo "Attempting build anyway - CMake may find alternative toolchain..." >&2
  else
    # Set up CMake toolchain for cross-compilation
    CMAKE_EXTRA_ARGS+=("-DCMAKE_SYSTEM_NAME=Windows")
    CMAKE_EXTRA_ARGS+=("-DCMAKE_C_COMPILER=${MINGW_PREFIX}-gcc")
    CMAKE_EXTRA_ARGS+=("-DCMAKE_CXX_COMPILER=${MINGW_PREFIX}-g++")
    CMAKE_EXTRA_ARGS+=("-DCMAKE_RC_COMPILER=${MINGW_PREFIX}-windres")
  fi
fi

# Cross-compilation for Android targets
if [[ "$OS_ID" == "android" ]]; then
  if [[ -z "${ANDROID_NDK:-}" ]]; then
    echo "Error: ANDROID_NDK environment variable not set" >&2
    echo "Download Android NDK from: https://developer.android.com/ndk/downloads" >&2
    echo "Then set: export ANDROID_NDK=/path/to/ndk" >&2
    exit 1
  fi
  
  case "$ARCH_ID" in
    arm64)
      ANDROID_ABI="arm64-v8a"
      ;;
    armv7)
      ANDROID_ABI="armeabi-v7a"
      ;;
    x86_64)
      ANDROID_ABI="x86_64"
      ;;
    *)
      echo "Error: Unsupported Android architecture: $ARCH_ID" >&2
      exit 1
      ;;
  esac
  
  CMAKE_EXTRA_ARGS+=("-DCMAKE_SYSTEM_NAME=Android")
  CMAKE_EXTRA_ARGS+=("-DCMAKE_ANDROID_NDK=$ANDROID_NDK")
  CMAKE_EXTRA_ARGS+=("-DCMAKE_ANDROID_ARCH_ABI=$ANDROID_ABI")
  CMAKE_EXTRA_ARGS+=("-DCMAKE_ANDROID_STL_TYPE=c++_static")
  CMAKE_EXTRA_ARGS+=("-DANDROID_NATIVE_API_LEVEL=21")
fi

# Cross-compilation for iOS targets
if [[ "$OS_ID" == "ios" ]]; then
  if [[ "$HOST_OS" != "macos" ]]; then
    echo "Error: iOS builds can only be done on macOS" >&2
    exit 1
  fi
  
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "Error: Xcode not installed" >&2
    echo "Install from Mac App Store" >&2
    exit 1
  fi
  
  CMAKE_EXTRA_ARGS+=("-DCMAKE_SYSTEM_NAME=iOS")
  CMAKE_EXTRA_ARGS+=("-DCMAKE_OSX_ARCHITECTURES=arm64")
  CMAKE_EXTRA_ARGS+=("-DCMAKE_OSX_DEPLOYMENT_TARGET=12.0")
  CMAKE_EXTRA_ARGS+=("-DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO")
fi

# Native macOS build: check dependencies and auto-detect Homebrew OpenSSL
if [[ "$OS_ID" == "macos" ]] && [[ $IS_CROSS_COMPILE -eq 0 ]]; then
  # Check for Xcode Command Line Tools
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "Error: Xcode Command Line Tools not installed" >&2
    echo "Install: xcode-select --install" >&2
    exit 1
  fi
  
  if command -v brew >/dev/null 2>&1; then
    # Check boost
    if ! brew list boost &>/dev/null && ! pkg-config --exists boost 2>/dev/null; then
      echo "Error: Boost not found" >&2
      echo "Install: brew install boost" >&2
      exit 1
    fi
    
    # Check and hint OpenSSL
    OPENSSL_ROOT="$(brew --prefix openssl@3 2>/dev/null || true)"
    if [[ -z "$OPENSSL_ROOT" ]] || [[ ! -e "$OPENSSL_ROOT/include/openssl/ssl.h" ]]; then
      OPENSSL_ROOT="$(brew --prefix openssl 2>/dev/null || true)"
    fi
    if [[ -n "$OPENSSL_ROOT" ]] && [[ -e "$OPENSSL_ROOT/include/openssl/ssl.h" ]]; then
      CMAKE_EXTRA_ARGS+=("-DOPENSSL_ROOT_DIR=$OPENSSL_ROOT")
    else
      echo "Error: OpenSSL not found via Homebrew" >&2
      echo "Install: brew install openssl" >&2
      exit 1
    fi
  else
    echo "Warning: Homebrew not found. Ensure boost and OpenSSL are discoverable by CMake." >&2
  fi
fi

echo "Building trojan core"
echo "  OS:          $OS_ID"
echo "  ARCH:        $ARCH_ID"
echo "  BUILD_TYPE:  $BUILD_TYPE"
echo "  VERSION:     $VERSION"
echo "  BUILD_DIR:   $BUILD_DIR"
echo "  DIST_DIR:    $DIST_DIR"

cmake -S "$PROJECT_ROOT" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE="$BUILD_TYPE" -DENABLE_MYSQL=OFF "${CMAKE_EXTRA_ARGS[@]}"
cmake --build "$BUILD_DIR" -- -j"$JOBS"

BIN_SRC="$BUILD_DIR/trojan"
if [[ "$OS_ID" == "windows" ]]; then
  # best-effort fallback if generator outputs .exe
  if [[ -f "$BUILD_DIR/trojan.exe" ]]; then
    BIN_SRC="$BUILD_DIR/trojan.exe"
  fi
fi

if [[ ! -f "$BIN_SRC" ]]; then
  echo "Build succeeded but trojan binary not found at: $BIN_SRC" >&2
  exit 1
fi

BIN_NAME="trojan-${VERSION}-${OS_ID}-${ARCH_ID}"
BIN_DST="$DIST_DIR/$BIN_NAME"

cp -f "$BIN_SRC" "$BIN_DST"
chmod +x "$BIN_DST" || true

# Optional strip (use cross-compile strip if available)
if [[ $STRIP_BIN -eq 1 ]]; then
  STRIP_CMD="strip"
  if [[ $IS_CROSS_COMPILE -eq 1 ]] && [[ "$OS_ID" == "windows" ]] && [[ -n "${MINGW_PREFIX:-}" ]]; then
    command -v "${MINGW_PREFIX}-strip" >/dev/null 2>&1 && STRIP_CMD="${MINGW_PREFIX}-strip"
  fi
  command -v "$STRIP_CMD" >/dev/null 2>&1 && "$STRIP_CMD" "$BIN_DST" 2>/dev/null || true
fi

# Convenience copy (latest)
cp -f "$BIN_DST" "$DIST_DIR/trojan"
chmod +x "$DIST_DIR/trojan" || true

echo "OK"
echo "  Artifact: $BIN_DST"
echo "  Latest:   $DIST_DIR/trojan"
