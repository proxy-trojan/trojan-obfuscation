#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  cat <<'EOF'
Usage:
  install-binary.sh --repo <owner/repo> --tool <name> [options]

Generic installer for a single executable binary distributed via GitHub Releases.

Required:
  --repo <owner/repo>
  --tool <name>

Options:
  --version latest|<tag>           (default: latest)
  --target auto|linux-amd64|linux-arm64  (default: auto)
  --install-dir <dir>             (default: /usr/local/bin)
  --dest-name <name>              (default: <tool>)
  --check-only                    Print plan only; do not write
  --help

Environment overrides:
  INSTALL_TARGET_KEY=linux-amd64|linux-arm64
EOF
}

require_value() {
  local flag="$1"
  local value="${2:-}"
  if [[ -z "$value" || "$value" == --* ]]; then
    echo "error: missing value for $flag" >&2
    exit 2
  fi
}

repo=""
tool=""
version="latest"
target="auto"
install_dir="/usr/local/bin"
dest_name=""
check_only=0

while (($# > 0)); do
  case "$1" in
    --repo)
      require_value "$1" "${2:-}"
      repo="$2"
      shift 2
      ;;
    --tool)
      require_value "$1" "${2:-}"
      tool="$2"
      shift 2
      ;;
    --version)
      require_value "$1" "${2:-}"
      version="$2"
      shift 2
      ;;
    --target)
      require_value "$1" "${2:-}"
      target="$2"
      shift 2
      ;;
    --install-dir)
      require_value "$1" "${2:-}"
      install_dir="$2"
      shift 2
      ;;
    --dest-name)
      require_value "$1" "${2:-}"
      dest_name="$2"
      shift 2
      ;;
    --check-only)
      check_only=1
      shift
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      print_usage >&2
      exit 2
      ;;
  esac

done

if [[ -z "$repo" || -z "$tool" ]]; then
  echo "error: --repo and --tool are required" >&2
  print_usage >&2
  exit 2
fi

if [[ -z "$dest_name" ]]; then
  dest_name="$tool"
fi

normalize_target() {
  local raw="$1"
  case "$raw" in
    linux-amd64|linux-arm64) echo "$raw" ;;
    *)
      echo "error: unsupported target '$raw' (expected linux-amd64|linux-arm64)" >&2
      exit 2
      ;;
  esac
}

detect_target() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64) echo "linux-amd64" ;;
    aarch64|arm64) echo "linux-arm64" ;;
    *)
      echo "error: unsupported arch '$arch' (expected x86_64 or aarch64/arm64)" >&2
      exit 1
      ;;
  esac
}

resolved_target=""
if [[ -n "${INSTALL_TARGET_KEY:-}" ]]; then
  resolved_target="$(normalize_target "${INSTALL_TARGET_KEY}")"
elif [[ "$target" == "auto" ]]; then
  resolved_target="$(detect_target)"
else
  resolved_target="$(normalize_target "$target")"
fi

asset_name="${tool}-${resolved_target}"
sha_name="${asset_name}.sha256"

base_url="https://github.com/${repo}"
if [[ "$version" == "latest" ]]; then
  asset_url="${base_url}/releases/latest/download/${asset_name}"
  sha_url="${base_url}/releases/latest/download/${sha_name}"
else
  asset_url="${base_url}/releases/download/${version}/${asset_name}"
  sha_url="${base_url}/releases/download/${version}/${sha_name}"
fi

dest_path="${install_dir}/${dest_name}"

echo "repo=${repo}"
echo "tool=${tool}"
echo "version=${version}"
echo "target=${resolved_target}"
echo "asset=${asset_name}"
echo "asset_url=${asset_url}"
echo "sha_url=${sha_url}"
echo "dest=${dest_path}"

download() {
  local url="$1"
  local out="$2"
  curl -fsSL "$url" -o "$out"
}

parse_sha256() {
  local sha_file="$1"
  # Accept both:
  #   <hash>  <filename>
  # and:
  #   <hash>
  awk 'NF{print $1; exit 0}' "$sha_file"
}

if [[ "$check_only" == "1" ]]; then
  echo "mode=check-only"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "error: curl is required" >&2
  exit 1
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "error: sha256sum is required" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

bin_tmp="$tmp_dir/${asset_name}"
sha_tmp="$tmp_dir/${sha_name}"

download "$sha_url" "$sha_tmp"
download "$asset_url" "$bin_tmp"

expected_sha="$(parse_sha256 "$sha_tmp")"
if [[ -z "$expected_sha" ]]; then
  echo "error: could not parse sha256 from $sha_name" >&2
  exit 1
fi

actual_sha="$(sha256sum "$bin_tmp" | awk '{print $1}')"
if [[ "$actual_sha" != "$expected_sha" ]]; then
  echo "error: sha256 mismatch" >&2
  echo "expected=$expected_sha" >&2
  echo "actual=$actual_sha" >&2
  exit 1
fi

install -d "$(dirname "$dest_path")"
install -m 0755 "$bin_tmp" "${dest_path}.tmp"
mv "${dest_path}.tmp" "$dest_path"

echo "installed=1"
