#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/detect-os.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/preflight.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/install-deps.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/install-core.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/configure-caddy.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/write-runtime-config.sh"

print_usage() {
  cat <<'EOF'
Usage: ./scripts/install/install-kernel.sh --www-domain <domain> --edge-domain <domain> --dns-provider <provider> [--check-only] [--help]

Generic Linux installer kernel skeleton for Trojan + Caddy ACME.

Required options:
  --www-domain <domain>   Public web domain served by Caddy
  --edge-domain <domain>  Trojan edge SNI / front-door domain
  --dns-provider <name>   DNS provider id used for ACME DNS-01

Modes:
  --check-only            Detection / plan only; do not install, do not write config,
                          do not start services
  --help                  Show this help message

Notes:
  - This task only provides the layered installer skeleton.
  - Real installation details can be filled by later tasks.
EOF
}

log_kv() {
  local key="$1"
  local value="$2"
  printf '%s=%s\n' "$key" "$value"
}

require_value() {
  local flag="$1"
  local value="${2:-}"
  if [[ -z "$value" || "$value" == --* ]]; then
    echo "error: missing value for $flag" >&2
    exit 1
  fi
}

www_domain=""
edge_domain=""
dns_provider=""
check_only=0

while (($# > 0)); do
  case "$1" in
    --www-domain)
      require_value "$1" "${2:-}"
      www_domain="$2"
      shift 2
      ;;
    --edge-domain)
      require_value "$1" "${2:-}"
      edge_domain="$2"
      shift 2
      ;;
    --dns-provider)
      require_value "$1" "${2:-}"
      dns_provider="$2"
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
      exit 1
      ;;
  esac
done

if [[ -z "$www_domain" || -z "$edge_domain" || -z "$dns_provider" ]]; then
  echo "error: --www-domain, --edge-domain, and --dns-provider are required" >&2
  print_usage >&2
  exit 1
fi

INSTALL_WWW_DOMAIN="$www_domain"
INSTALL_EDGE_DOMAIN="$edge_domain"
INSTALL_DNS_PROVIDER="$dns_provider"
INSTALL_CHECK_ONLY="$check_only"
INSTALL_ROOT_PREFIX="${INSTALL_ROOT_PREFIX:-}"
INSTALL_ENV_FILE="${INSTALL_ROOT_PREFIX}/etc/trojan-pro/env"

if [[ "$check_only" -eq 1 ]]; then
  mode_label="check-only"
else
  mode_label="apply"
fi

log_kv "installer" "install-kernel"
log_kv "mode" "$mode_label"
log_kv "www_domain" "$www_domain"
log_kv "edge_domain" "$edge_domain"
log_kv "dns_provider" "$dns_provider"

if [[ "$check_only" -ne 1 ]]; then
  echo "error: apply mode is not implemented yet; use --check-only" >&2
  exit 1
fi

phase_preflight
phase_detect_os
phase_install_deps
phase_install_core
phase_configure_caddy
phase_write_runtime_config
