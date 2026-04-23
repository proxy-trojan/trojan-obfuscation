#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLIENT_DIR="$PROJECT_ROOT/client"

started_at_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
branch="$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD)"
commit_short="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD)"

echo "== validate_iter3_truthful_daily_use =="
echo "project_root=$PROJECT_ROOT"
echo "branch=$branch"
echo "commit=$commit_short"
echo "started_at_utc=$started_at_utc"
echo

echo "[1/4] python tests (daily action perf baseline regression gate)"
python3 -m pip install --user pytest
python3 -m pytest "$PROJECT_ROOT/scripts/tests/test_compute_daily_action_perf_baseline.py" -q
echo "✅ [1/4] pass"
echo

echo "[2/4] flutter analyze (client)"
(
  cd "$CLIENT_DIR"
  flutter analyze
)
echo "✅ [2/4] pass"
echo

echo "[3/4] flutter test (Iter-3 truthful daily-use key suite)"
(
  cd "$CLIENT_DIR"
  flutter test \
    test/features/profiles/presentation/high_frequency_actions_strip_test.dart \
    test/features/controller/domain/controller_runtime_session_test.dart \
    test/features/dashboard/presentation/dashboard_page_test.dart \
    test/features/advanced/presentation/advanced_page_test.dart
)
echo "✅ [3/4] pass"
echo

finished_at_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "[4/4] done"
echo "finished_at_utc=$finished_at_utc"
echo

echo "---"
echo "Iter-3 truthful daily-use validation evidence"
echo "- Script: ./scripts/validate_iter3_truthful_daily_use.sh"
echo "- Branch: $branch"
echo "- Commit: $commit_short"
echo "- Started: $started_at_utc"
echo "- Finished: $finished_at_utc"
