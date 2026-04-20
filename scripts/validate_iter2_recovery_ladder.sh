#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLIENT_DIR="$PROJECT_ROOT/client"

started_at_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
branch="$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD)"
commit_short="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD)"

echo "== validate_iter2_recovery_ladder =="
echo "project_root=$PROJECT_ROOT"
echo "branch=$branch"
echo "commit=$commit_short"
echo "started_at_utc=$started_at_utc"
echo

echo "[1/4] python tests (ux metrics snapshot)"
python3 -m pytest "$PROJECT_ROOT/scripts/tests/test_compute_ux_metrics_snapshot.py" -q
echo "✅ [1/4] pass"
echo

echo "[2/4] flutter analyze (client)"
(
  cd "$CLIENT_DIR"
  flutter analyze
)
echo "✅ [2/4] pass"
echo

echo "[3/4] flutter test (Iter-2 recovery ladder key suite)"
(
  cd "$CLIENT_DIR"
  flutter test \
    test/features/controller/domain/recovery_ladder_policy_test.dart \
    test/features/profiles/presentation/next_action_policy_test.dart \
    test/features/dashboard/presentation/dashboard_guide_policy_test.dart \
    test/features/profiles/presentation/profile_connection_action_policy_test.dart \
    test/features/controller/domain/runtime_action_safety_test.dart \
    test/features/controller/domain/runtime_operator_advice_test.dart
)
echo "✅ [3/4] pass"
echo

finished_at_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "[4/4] done"
echo "finished_at_utc=$finished_at_utc"
echo

echo "---"
echo "Recovery Ladder validation evidence"
echo "- Script: ./scripts/validate_iter2_recovery_ladder.sh"
echo "- Branch: $branch"
echo "- Commit: $commit_short"
echo "- Started: $started_at_utc"
echo "- Finished: $finished_at_utc"
