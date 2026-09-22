#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

help="$(make -C "$ROOT" -s help)"
printf '%s\n' "$help" | grep -q 'make upstream' \
  || fail "make help must mention make upstream"

make -C "$ROOT" upstream
make -C "$ROOT" upstream >/dev/null

expect() {
  local dir="$1" want="$2" got
  # config, not `git remote get-url`: a global insteadOf rewrite injects
  # credentials into the displayed URL.
  got="$(git -C "$ROOT/$dir" config --get remote.upstream.url)"
  [[ "$got" == "$want" ]] || fail "$dir upstream is $got, want $want"
  git -C "$ROOT/$dir" rev-parse --verify --quiet refs/remotes/upstream/main >/dev/null \
    || fail "$dir did not fetch upstream/main"
}

expect hub "https://github.com/urantia-hub/urantia-hub.git"
expect api "https://github.com/urantia-hub/urantia-dev-api.git"
expect data-sources "https://github.com/urantia-hub/urantia-data-sources.git"
expect pipeline/langs/spanish "https://github.com/URANTIA-BOOK/source.git"
expect pipeline/langs/spanish_eur "https://github.com/URANTIA-BOOK/spanish.git"

if git -C "$ROOT/pipeline" remote get-url upstream >/dev/null 2>&1; then
  fail "pipeline is not a fork and must not grow an upstream remote"
fi
if git -C "$ROOT/pipeline/source" remote get-url upstream >/dev/null 2>&1; then
  fail "English source is not a fork and must not grow an upstream remote"
fi

echo "upstream: fork submodules track their GitHub parents"
