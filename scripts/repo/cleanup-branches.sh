#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  cat <<'EOF'
Usage: ./scripts/repo/cleanup-branches.sh [--apply] [--help]

Default mode is dry-run:
  - prints which local and remote branches would be deleted
  - does not delete anything unless --apply is provided

Deletion rules:
  - local candidates: all local branches except main and the current branch
  - remote candidates: all origin/* refs except origin/main, origin/HEAD,
    and the current branch's origin counterpart

Options:
  --apply   Actually delete eligible branches
  --help    Show this help message
EOF
}

mode="dry-run"

while (($# > 0)); do
  case "$1" in
    --apply)
      mode="apply"
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo >&2
      print_usage >&2
      exit 1
      ;;
  esac
  shift
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: must be run inside a git work tree" >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
current_branch="$(git branch --show-current || true)"
if [[ -z "$current_branch" ]]; then
  current_branch="HEAD"
fi

local_candidates=()
while IFS= read -r branch; do
  [[ -z "$branch" ]] && continue
  [[ "$branch" == "main" ]] && continue
  [[ "$branch" == "$current_branch" ]] && continue
  local_candidates+=("$branch")
done < <(git for-each-ref --format='%(refname:short)' refs/heads)

remote_candidates=()
if git remote get-url origin >/dev/null 2>&1; then
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    case "$ref" in
      origin/main|origin/HEAD)
        continue
        ;;
    esac
    if [[ "$current_branch" != "HEAD" && "$ref" == "origin/$current_branch" ]]; then
      continue
    fi
    remote_candidates+=("$ref")
  done < <(git for-each-ref --format='%(refname:short)' refs/remotes/origin)
fi

echo "== cleanup-branches =="
echo "repo_root=$repo_root"
echo "current_branch=$current_branch"
echo "mode=$mode"
echo

if [[ ${#local_candidates[@]} -eq 0 && ${#remote_candidates[@]} -eq 0 ]]; then
  echo "no eligible branches found"
  exit 0
fi

for branch in "${local_candidates[@]}"; do
  if [[ "$mode" == "dry-run" ]]; then
    echo "would delete local branch: $branch"
  else
    git branch -D "$branch" >/dev/null
    echo "deleted local branch: $branch"
  fi
done

remote_deleted=0
for ref in "${remote_candidates[@]}"; do
  remote_branch="${ref#origin/}"
  if [[ "$mode" == "dry-run" ]]; then
    echo "would delete remote branch: $ref"
  else
    git push origin --delete "$remote_branch" >/dev/null
    echo "deleted remote branch: $ref"
    remote_deleted=1
  fi
done

if [[ "$mode" == "apply" && "$remote_deleted" -eq 1 ]]; then
  git fetch origin --prune >/dev/null
fi
