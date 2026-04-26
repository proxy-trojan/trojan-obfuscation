#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_BUNDLE="$(mktemp /tmp/trojan-pro-client-profile-XXXXXX.json)"

cleanup() {
  rm -f "$TMP_BUNDLE"
}
trap cleanup EXIT

started_at_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
branch="$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD)"
commit_short="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD)"

DIRECT_FIXTURE="$PROJECT_ROOT/scripts/tests/fixtures/clash_rules_direct.sample.txt"
PROXY_FIXTURE="$PROJECT_ROOT/scripts/tests/fixtures/clash_rules_proxy.sample.txt"
REJECT_FIXTURE="$PROJECT_ROOT/scripts/tests/fixtures/clash_rules_reject.sample.txt"

cd "$PROJECT_ROOT"

echo "== validate_repo_cleanup_installer_routing =="
echo "project_root=$PROJECT_ROOT"
echo "branch=$branch"
echo "commit=$commit_short"
echo "started_at_utc=$started_at_utc"
echo "tmp_bundle=$TMP_BUNDLE"
echo

echo "[1/4] cleanup dry-run"
bash scripts/repo/cleanup-branches.sh
echo "✅ [1/4] pass"
echo

echo "[2/4] installer --check-only"
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-token}" \
  bash scripts/install/install-kernel.sh \
    --www-domain www.example.com \
    --edge-domain edge.example.com \
    --dns-provider cloudflare \
    --check-only
echo "✅ [2/4] pass"
echo

echo "[3/4] bundle generator fixture run"
python3 scripts/config/generate-client-bundle.py \
  --direct "$DIRECT_FIXTURE" \
  --proxy "$PROXY_FIXTURE" \
  --reject "$REJECT_FIXTURE" \
  --output "$TMP_BUNDLE"
test -s "$TMP_BUNDLE"
echo "✅ [3/4] pass"
echo

echo "[4/4] docs bilingual index test"
python3 -m pytest scripts/tests/test_docs_bilingual_index.py -q
echo "✅ [4/4] pass"
echo

finished_at_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "finished_at_utc=$finished_at_utc"
echo
echo "PASS: validate_repo_cleanup_installer_routing"
