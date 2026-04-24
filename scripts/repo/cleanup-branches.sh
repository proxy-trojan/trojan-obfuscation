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

Safety notes:
  - --apply performs real branch deletions; run dry-run first
  - local branches are deleted with safe mode (git branch -d), not force-delete
  - --apply is refused in detached HEAD state

Options:
  --apply   Actually delete eligible branches
  --help    Show this help message
EOF
}

collapse_output() {
  local raw_output="$1"
  printf '%s' "$raw_output" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//'
}

print_detail_list() {
  local title="$1"
  shift

  if (($# == 0)); then
    return 0
  fi

  echo "$title"
  local item
  for item in "$@"; do
    echo "  - $item"
  done
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
is_detached=0
if current_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
  :
else
  is_detached=1
  current_branch="HEAD"
fi

if [[ "$mode" == "apply" && "$is_detached" -eq 1 ]]; then
  echo "error: refusing --apply in detached HEAD state" >&2
  exit 1
fi

if [[ "$is_detached" -eq 1 ]]; then
  echo "warning: detached HEAD detected; dry-run will continue but --apply is refused" >&2
fi

local_candidates=()
while IFS= read -r branch; do
  [[ -z "$branch" ]] && continue
  [[ "$branch" == "main" ]] && continue
  [[ "$branch" == "$current_branch" ]] && continue
  local_candidates+=("$branch")
done < <(git for-each-ref --format='%(refname:short)' refs/heads)

remote_candidates=()
fetch_warnings=()
if git remote get-url origin >/dev/null 2>&1; then
  if ! fetch_output="$(git fetch origin --prune 2>&1)"; then
    fetch_reason="$(collapse_output "$fetch_output")"
    fetch_warnings+=("git fetch origin --prune failed; continuing with local remote-tracking refs :: $fetch_reason")
    echo "warning: git fetch origin --prune failed; continuing with local remote-tracking refs" >&2
    [[ -n "$fetch_reason" ]] && echo "warning: $fetch_reason" >&2
  fi

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

local_deleted=()
local_skipped=()
remote_deleted=()
remote_skipped=()
failures=()

if [[ ${#local_candidates[@]} -eq 0 && ${#remote_candidates[@]} -eq 0 ]]; then
  echo "no eligible branches found"
else
  for branch in "${local_candidates[@]}"; do
    if [[ "$mode" == "dry-run" ]]; then
      echo "would delete local branch: $branch"
      continue
    fi

    if delete_output="$(git branch -d "$branch" 2>&1)"; then
      local_deleted+=("$branch")
      echo "deleted local branch: $branch"
      continue
    fi

    delete_reason="$(collapse_output "$delete_output")"
    if [[ "$delete_reason" == *"not fully merged"* ]]; then
      local_skipped+=("$branch :: $delete_reason")
      echo "skipped local branch: $branch"
      echo "  reason: $delete_reason"
    else
      failures+=("local branch $branch :: $delete_reason")
      echo "failed local branch: $branch" >&2
      echo "  reason: $delete_reason" >&2
    fi
  done

  for ref in "${remote_candidates[@]}"; do
    remote_branch="${ref#origin/}"
    if [[ "$mode" == "dry-run" ]]; then
      echo "would delete remote branch: $ref"
      continue
    fi

    if delete_output="$(git push origin --delete "$remote_branch" 2>&1)"; then
      remote_deleted+=("$ref")
      echo "deleted remote branch: $ref"
      continue
    fi

    delete_reason="$(collapse_output "$delete_output")"
    if [[ "$delete_reason" == *"remote ref does not exist"* ]]; then
      remote_skipped+=("$ref :: $delete_reason")
      echo "skipped remote branch: $ref"
      echo "  reason: $delete_reason"
      git update-ref -d "refs/remotes/$ref" >/dev/null 2>&1 || true
    else
      failures+=("remote branch $ref :: $delete_reason")
      echo "failed remote branch: $ref" >&2
      echo "  reason: $delete_reason" >&2
    fi
  done
fi

echo
echo "summary:"
echo "  local_candidates=${#local_candidates[@]}"
echo "  remote_candidates=${#remote_candidates[@]}"
echo "  local_deleted=${#local_deleted[@]}"
echo "  local_skipped=${#local_skipped[@]}"
echo "  remote_deleted=${#remote_deleted[@]}"
echo "  remote_skipped=${#remote_skipped[@]}"
echo "  warnings=${#fetch_warnings[@]}"
echo "  failures=${#failures[@]}"

print_detail_list "fetch warnings:" "${fetch_warnings[@]}"
print_detail_list "skipped local branches:" "${local_skipped[@]}"
print_detail_list "skipped remote branches:" "${remote_skipped[@]}"
print_detail_list "failures:" "${failures[@]}"

if [[ ${#failures[@]} -gt 0 ]]; then
  exit 1
fi
