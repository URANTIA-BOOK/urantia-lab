#!/usr/bin/env bash
# Point each fork submodule at its GitHub parent and fetch that default branch.
# The parent comes from `gh repo view`, which is the fork record.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_FETCH="${UPSTREAM_FETCH:-always}"

# `gh repo view` with no argument prefers a remote named upstream. Always
# ask about origin, or the second run walks the parent chain.
origin_slug() {
  local url
  url="$(git config --get remote.origin.url)"
  url="${url%.git}"
  case "$url" in
    git@github.com:*) url="${url#git@github.com:}" ;;
    ssh://git@github.com/*) url="${url#ssh://git@github.com/}" ;;
    https://*|http://*)
      url="${url#*://}"
      url="${url#*@}"
      url="${url#github.com/}"
      ;;
  esac
  printf '%s\n' "$url"
}

ensure_here() {
  local label="${1:-$(basename "$PWD")}"
  local origin slug url branch have
  command -v gh >/dev/null 2>&1 || {
    echo "gh is required to read fork parents" >&2
    exit 1
  }
  origin="$(origin_slug)"
  slug="$(gh repo view "$origin" --json isFork,parent --jq 'if .isFork then "\(.parent.owner.login)/\(.parent.name)" else "" end')"
  if [[ -z "$slug" ]]; then
    echo "==> $label is not a fork"
    return 0
  fi
  url="https://github.com/${slug}.git"
  # Compare the stored URL. `git remote get-url` expands insteadOf and can
  # show injected credentials.
  if git config --get remote.upstream.url >/dev/null 2>&1; then
    if [[ "$(git config --get remote.upstream.url)" != "$url" ]]; then
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
