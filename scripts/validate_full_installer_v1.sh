#!/usr/bin/env bash
set -euo pipefail

echo "== validate_full_installer_v1 =="
echo "[1/4] manifest + provider registry"
python3 -m pytest scripts/tests/test_install_manifest_runtime.py scripts/tests/test_dns_provider_registry.py -q

echo "[2/4] render + bundle export"
python3 -m pytest scripts/tests/test_render_install_runtime.py scripts/tests/test_export_client_bundle_from_manifest.py scripts/tests/test_generate_client_bundle.py -q

echo "[3/4] installer apply flow"
python3 -m pytest scripts/tests/test_install_binary_contract.py scripts/tests/test_install_preflight_contract.py scripts/tests/test_install_kernel_apply_flow.py -q

echo "[4/4] tp cli"
python3 -m pytest scripts/tests/test_tp_cli_contract.py scripts/tests/test_tp_cli_mutations.py -q

echo "PASS: validate_full_installer_v1"
