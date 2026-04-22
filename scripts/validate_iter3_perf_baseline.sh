#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

started_at_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
branch="$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD)"
commit_short="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD)"

echo "== validate_iter3_perf_baseline =="
echo "project_root=$PROJECT_ROOT"
echo "branch=$branch"
echo "commit=$commit_short"
echo "started_at_utc=$started_at_utc"
echo

echo "[1/2] python tests (daily action perf baseline regression gate)"
python3 -m pytest "$PROJECT_ROOT/scripts/tests/test_compute_daily_action_perf_baseline.py" -q
echo "✅ [1/2] pass"
echo

finished_at_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "[2/2] done"
echo "finished_at_utc=$finished_at_utc"
echo

echo "---"
echo "Iter-3 performance baseline validation evidence"
echo "- Script: ./scripts/validate_iter3_perf_baseline.sh"
echo "- Branch: $branch"
echo "- Commit: $commit_short"
echo "- Started: $started_at_utc"
echo "- Finished: $finished_at_utc"
