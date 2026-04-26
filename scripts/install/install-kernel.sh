#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/common.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/detect-os.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/preflight.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/install-deps.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/install-binaries.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/install-core.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/configure-caddy.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/write-runtime-config.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/cert-bootstrap.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/activate-services.sh"

print_usage() {
  cat <<'EOF'
Usage: ./scripts/install/install-kernel.sh --www-domain <domain> --edge-domain <domain> --dns-provider <provider> [--check-only|--apply] [--help]

Manifest-backed Linux installer kernel for Trojan + Caddy ACME (DNS-01).

Required options:
  --www-domain <domain>   Public web domain served by Caddy
  --edge-domain <domain>  Trojan edge SNI / front-door domain
  --dns-provider <name>   DNS provider id used for ACME DNS-01

Modes:
  --check-only            Detection / plan only; do not install, do not write config,
                          do not start services
  --apply                 Execute the installer flow under the selected root prefix
  --help                  Show this help message

Notes:
  - Provider credentials are read from `/etc/trojan-pro/env` and the current process env.
  - `INSTALL_ROOT_PREFIX` can be set for staged runs (e.g. `/tmp/root`).
  - Binary download/verify is controlled by `scripts/install/artifacts/binaries.lock.json`.
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
apply_mode=0

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
    --apply)
      apply_mode=1
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
INSTALL_APPLY="$apply_mode"
INSTALL_ROOT_PREFIX="${INSTALL_ROOT_PREFIX:-}"
INSTALL_ENV_FILE="${INSTALL_ROOT_PREFIX}/etc/trojan-pro/env"
INSTALL_BINARIES_LOCK="${INSTALL_BINARIES_LOCK:-$SCRIPT_DIR/artifacts/binaries.lock.json}"
INSTALL_TARGET_KEY="${INSTALL_TARGET_KEY:-linux-amd64}"
INSTALL_TROJAN_BIN="${INSTALL_ROOT_PREFIX}/usr/local/bin/trojan"
INSTALL_CADDY_BIN="${INSTALL_ROOT_PREFIX}/usr/local/bin/caddy-custom"
INSTALL_TROJAN_LOCAL_PORT="${INSTALL_TROJAN_LOCAL_PORT:-8443}"

if [[ "$check_only" -eq 1 ]]; then
  mode_label="check-only"
elif [[ "$apply_mode" -eq 1 ]]; then
  mode_label="apply"
else
  mode_label="unset"
fi

log_kv "installer" "install-kernel"
log_kv "mode" "$mode_label"
log_kv "www_domain" "$www_domain"
log_kv "edge_domain" "$edge_domain"
log_kv "dns_provider" "$dns_provider"

if [[ "$check_only" -eq 0 && "$apply_mode" -eq 0 ]]; then
  echo "error: either --check-only or --apply is required" >&2
  print_usage >&2
  exit 1
fi

phase_preflight
phase_detect_os
phase_install_deps

if [[ "$apply_mode" -eq 1 ]]; then
  backup_dir="${INSTALL_ROOT_PREFIX}/var/backups/trojan-pro/last-known-good"
  backup_if_exists "${INSTALL_ROOT_PREFIX}/etc/trojan-pro/install-manifest.json" "$backup_dir/install-manifest.json"
  backup_if_exists "${INSTALL_ROOT_PREFIX}/etc/trojan-pro/config.json" "$backup_dir/config.json"
  backup_if_exists "${INSTALL_ROOT_PREFIX}/etc/caddy/Caddyfile" "$backup_dir/Caddyfile"
fi

phase_install_core
phase_write_runtime_config
phase_configure_caddy
if [[ "$apply_mode" -eq 1 ]]; then
  install -m 0755 "$SCRIPT_DIR/runtime/cli.py" "${INSTALL_ROOT_PREFIX}/usr/local/bin/tp"
  ln -sfn "${INSTALL_ROOT_PREFIX}/usr/local/bin/tp" "${INSTALL_ROOT_PREFIX}/usr/local/bin/tpctl"
  phase_cert_bootstrap
  phase_activate_services
  if ! phase_validate; then
    restore_backup "${INSTALL_ROOT_PREFIX}/etc/trojan-pro/install-manifest.json" "$backup_dir/install-manifest.json"
    restore_backup "${INSTALL_ROOT_PREFIX}/etc/trojan-pro/config.json" "$backup_dir/config.json"
    restore_backup "${INSTALL_ROOT_PREFIX}/etc/caddy/Caddyfile" "$backup_dir/Caddyfile"
    exit 1
  fi
fi
