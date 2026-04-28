#!/usr/bin/env bash
set -euo pipefail

# tp-install.sh
#
# Bootstrap installer for the `tp` CLI distributed via GitHub Releases.
#
# Responsibilities:
# - Detect Linux arch (amd64/arm64)
# - Download `tp` from GitHub Releases (latest) and verify sha256 sidecar
# - Install `tp` to /usr/local/bin/tp
# - Run `tp install` (interactive by default)
#
# Usage:
#   curl -fsSL https://github.com/<owner>/<repo>/releases/latest/download/tp-install.sh | sudo bash
#
# Pass-through args to `tp install`:
#   curl -fsSL .../tp-install.sh | sudo bash -s -- --lang en

REPO="proxy-trojan/trojan-obfuscation"
TOOL="tp"
INSTALL_DIR="/usr/local/bin"
DEST_NAME="tp"

print_err() {
  echo "$*" >&2
}

DNS_PROVIDER_OPTIONS=(cloudflare route53 alidns dnspod gcloud)

prompt_tty_line() {
  local prompt="$1"
  local value=""
  printf '%s\n' "$prompt" >/dev/tty
  read -r -p "> " value </dev/tty
  printf '%s' "$value"
}

prompt_tty_dns_provider() {
  local lang="$1"
  local raw=""
  local index=""
  if [[ "$lang" == "zh-CN" ]]; then
    printf 'DNS provider:\n' >/dev/tty
  else
    printf 'dns provider:\n' >/dev/tty
  fi
  local i=1
  for provider in "${DNS_PROVIDER_OPTIONS[@]}"; do
    printf '%s) %s\n' "$i" "$provider" >/dev/tty
    i=$((i + 1))
  done
  read -r -p "> " raw </dev/tty
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    index=$((raw - 1))
    if (( index >= 0 && index < ${#DNS_PROVIDER_OPTIONS[@]} )); then
      printf '%s' "${DNS_PROVIDER_OPTIONS[$index]}"
      return 0
    fi
  fi
  printf '%s' "$raw"
}

collect_interactive_args_from_tty() {
  local lang_choice lang www_domain edge_domain dns_provider confirm

  printf 'Select language / 选择语言:\n' >/dev/tty
  printf '1) 中文\n' >/dev/tty
  printf '2) English\n' >/dev/tty
  read -r -p "> " lang_choice </dev/tty
  if [[ "$lang_choice" == "1" ]]; then
    lang="zh-CN"
  else
    lang="en"
  fi

  if [[ "$lang" == "zh-CN" ]]; then
    www_domain="$(prompt_tty_line 'www 域名:')"
    edge_domain="$(prompt_tty_line 'edge 域名:')"
    dns_provider="$(prompt_tty_dns_provider "$lang")"
    printf '1) y / Y / yes / YES\n' >/dev/tty
    confirm="$(prompt_tty_line '输入 y/Y/yes/YES 继续，其他任意输入将中止：')"
  else
    www_domain="$(prompt_tty_line 'www domain:')"
    edge_domain="$(prompt_tty_line 'edge domain:')"
    dns_provider="$(prompt_tty_dns_provider "$lang")"
    printf '1) y / Y / yes / YES\n' >/dev/tty
    confirm="$(prompt_tty_line 'Type y/Y/yes/YES to continue, anything else to abort:')"
  fi

  case "${confirm,,}" in
    y|yes)
      ;;
    *)
      if [[ "$lang" == "zh-CN" ]]; then
        print_err '已中止'
      else
        print_err 'aborted'
      fi
      exit 2
      ;;
  esac

  args_to_tp_install=(
    --non-interactive
    --lang "$lang"
    --www-domain "$www_domain"
    --edge-domain "$edge_domain"
    --dns-provider "$dns_provider"
    --yes
  )
}

require_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    print_err "error: missing required command: $name"
    exit 1
  fi
}

detect_target() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64) echo "linux-amd64" ;;
    aarch64|arm64) echo "linux-arm64" ;;
    *)
      print_err "error: unsupported arch '$arch' (expected x86_64 or aarch64/arm64)"
      exit 1
      ;;
  esac
}

parse_sha256() {
  local sha_file="$1"
  # Accept both: '<hash>  <filename>' or '<hash>'
  awk 'NF{print $1; exit 0}' "$sha_file"
}

# Everything after '--' is forwarded to `tp install`.
args_to_tp_install=()
if (($# > 0)); then
  if [[ "$1" == "--" ]]; then
    shift
    args_to_tp_install=("$@")
  else
    # Keep strict: require '--' separator for passthrough.
    print_err "error: unexpected arguments. Use: sudo bash -s -- -- <tp install args>"
    exit 2
  fi
fi

require_cmd curl
require_cmd sha256sum

resolved_target="$(detect_target)"
asset_name="${TOOL}-${resolved_target}"
sha_name="${asset_name}.sha256"

base_url="https://github.com/${REPO}"
asset_url="${base_url}/releases/latest/download/${asset_name}"
sha_url="${base_url}/releases/latest/download/${sha_name}"

dest_path="${INSTALL_DIR}/${DEST_NAME}"

echo "repo=${REPO}"
echo "tool=${TOOL}"
echo "target=${resolved_target}"
echo "asset=${asset_name}"
echo "asset_url=${asset_url}"
echo "sha_url=${sha_url}"
echo "dest=${dest_path}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

bin_tmp="$tmp_dir/${asset_name}"
sha_tmp="$tmp_dir/${sha_name}"

curl -fsSL "$sha_url" -o "$sha_tmp"
curl -fsSL "$asset_url" -o "$bin_tmp"

expected_sha="$(parse_sha256 "$sha_tmp")"
if [[ -z "$expected_sha" ]]; then
  print_err "error: could not parse sha256 from ${sha_name}"
  exit 1
fi

actual_sha="$(sha256sum "$bin_tmp" | awk '{print $1}')"
if [[ "$actual_sha" != "$expected_sha" ]]; then
  print_err "error: sha256 mismatch"
  print_err "expected=$expected_sha"
  print_err "actual=$actual_sha"
  exit 1
fi

install -d "$(dirname "$dest_path")"
install -m 0755 "$bin_tmp" "${dest_path}.tmp"
mv "${dest_path}.tmp" "$dest_path"

echo "installed=1"

echo "running: tp install ${args_to_tp_install[*]}"

# When executed as `curl ... | sudo bash`, stdin is the script stream (EOF after read).
# Also, under sudo/use_pty, handing /dev/tty directly to a child onefile binary can
# trigger job-control stops (SIGTTIN) when the real reader is no longer in the tty's
# foreground process group. So in the pipe-stdin case we collect answers in this shell
# from /dev/tty first, then exec `tp install --non-interactive ...`.
if [[ -t 0 ]]; then
  exec "$dest_path" install "${args_to_tp_install[@]}"
fi

if ((${#args_to_tp_install[@]} > 0)); then
  exec "$dest_path" install "${args_to_tp_install[@]}"
fi

if [[ -r /dev/tty ]] && { : </dev/tty; } 2>/dev/null; then
  collect_interactive_args_from_tty
  echo "running: tp install ${args_to_tp_install[*]}"
  exec "$dest_path" install "${args_to_tp_install[@]}"
fi

print_err "error: no interactive stdin available (stdin is not a TTY and /dev/tty is not usable)."
print_err "hint:"
print_err "  - If you want interactive install, run from a real terminal (SSH with -t / allocate a PTY)."
print_err "  - Otherwise, re-run with passthrough args, e.g.:"
print_err "      curl -fsSL .../tp-install.sh | sudo bash -s -- -- --non-interactive --lang en --www-domain ... --edge-domain ... --dns-provider ... --yes"
exit 2
