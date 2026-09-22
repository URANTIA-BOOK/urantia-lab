#!/usr/bin/env bash
# Point each fork submodule at its GitHub parent and fetch that default branch.
# The parent comes from `gh repo view`, which is the fork record.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_FETCH="${UPSTREAM_FETCH:-always}"

ensure_here() {
  local label="${1:-$(basename "$PWD")}"
  local slug url branch have
  command -v gh >/dev/null 2>&1 || {
    echo "gh is required to read fork parents" >&2
    exit 1
  }
  slug="$(gh repo view --json isFork,parent --jq 'if .isFork then "\(.parent.owner.login)/\(.parent.name)" else "" end')"
  if [[ -z "$slug" ]]; then
    echo "==> $label is not a fork"
    return 0
  fi
  url="https://github.com/${slug}.git"
  if git remote get-url upstream >/dev/null 2>&1; then
    if [[ "$(git remote get-url upstream)" != "$url" ]]; then
      git remote set-url upstream "$url"
    fi
  else
    git remote add upstream "$url"
  fi
  branch="$(gh repo view "$slug" --json defaultBranchRef --jq .defaultBranchRef.name)"
  echo "==> $label upstream $url ($branch)"
  have="refs/remotes/upstream/${branch}"
  if [[ "$UPSTREAM_FETCH" == "always" ]] || ! git rev-parse --verify --quiet "$have" >/dev/null; then
    git fetch --quiet upstream "$branch"
  fi
}

if [[ "${1:-}" == "--here" ]]; then
  ensure_here "${2:-}"
  exit 0
fi

git -C "$REPOSITORY_ROOT" submodule foreach --recursive \
  "UPSTREAM_FETCH=$(printf '%q' "$UPSTREAM_FETCH") bash $(printf '%q' "$SCRIPT_DIR/upstream-remotes.sh") --here \"\$displaypath\""
