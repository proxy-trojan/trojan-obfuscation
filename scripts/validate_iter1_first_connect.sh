#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLIENT_DIR="$PROJECT_ROOT/client"

echo "== validate_iter1_first_connect =="
echo "project_root=$PROJECT_ROOT"

echo

echo "[1/4] python tests (ux metrics snapshot)"
python3 -m pytest "$PROJECT_ROOT/scripts/tests/test_compute_ux_metrics_snapshot.py" -q

echo

echo "[2/4] flutter analyze (client)"
(
  cd "$CLIENT_DIR"
  flutter analyze
)

echo

echo "[3/4] flutter test (Iter-1 key suite)"
(
  cd "$CLIENT_DIR"
  flutter test \
    test/features/profiles/presentation/profiles_page_action_gating_test.dart \
    test/features/profiles/presentation/first_connect_guidance_card_test.dart \
    test/features/profiles/presentation/high_frequency_actions_strip_test.dart \
    test/features/diagnostics/presentation/export_summary_sheet_test.dart \
    test/features/diagnostics/application/diagnostics_export_service_test.dart \
    test/features/controller/application/adapter_backed_client_controller_test.dart \
    test/features/profiles/presentation/profile_connection_action_policy_test.dart
)

echo

echo "[4/4] done"
