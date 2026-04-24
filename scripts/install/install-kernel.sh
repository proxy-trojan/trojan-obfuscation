#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/detect-os.sh"
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
Usage: ./scripts/install/install-kernel.sh --domain <domain> --email <email> --password <password> [--check-only] [--help]

Generic Linux installer kernel skeleton for Trojan + Caddy ACME.

Required options:
  --domain <domain>      Public domain for Caddy ACME / server routing
  --email <email>        Contact email for ACME registration
  --password <password>  Trojan runtime password

Modes:
  --check-only           Detection / plan only; do not install, do not write config,
                         do not start services
  --help                 Show this help message

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

domain=""
email=""
password=""
check_only=0

while (($# > 0)); do
  case "$1" in
    --domain)
      require_value "$1" "${2:-}"
      domain="$2"
      shift 2
      ;;
    --email)
      require_value "$1" "${2:-}"
      email="$2"
      shift 2
      ;;
    --password)
      require_value "$1" "${2:-}"
      password="$2"
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

if [[ -z "$domain" || -z "$email" || -z "$password" ]]; then
  echo "error: --domain, --email, and --password are required" >&2
  print_usage >&2
  exit 1
fi

INSTALL_DOMAIN="$domain"
INSTALL_EMAIL="$email"
INSTALL_PASSWORD="$password"
INSTALL_CHECK_ONLY="$check_only"

if [[ "$check_only" -eq 1 ]]; then
  mode_label="check-only"
else
  mode_label="apply"
fi

log_kv "installer" "install-kernel"
log_kv "mode" "$mode_label"
log_kv "domain" "$domain"
log_kv "email" "$email"

if [[ "$check_only" -ne 1 ]]; then
  echo "error: apply mode is not implemented yet; use --check-only" >&2
  exit 1
fi

phase_detect_os
phase_install_deps
phase_install_core
phase_configure_caddy
phase_write_runtime_config
