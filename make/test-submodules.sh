#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODULES="$ROOT/.gitmodules"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f "$MODULES" ]] || fail "missing .gitmodules"

for name in hub api pipeline data-sources; do
  git config -f "$MODULES" --get "submodule.$name.path" >/dev/null \
    || fail "submodule $name must be declared"
  git config -f "$MODULES" --get "submodule.$name.branch" | grep -qx main \
    || fail "submodule $name must track main"
  url="$(git config -f "$MODULES" --get "submodule.$name.url")"
  [[ "$url" == ../* ]] || fail "submodule $name must use a relative ../ URL (got $url)"
  [[ -e "$ROOT/$name/.git" ]] || fail "submodule $name is not checked out (run: git clone --recurse-submodules)"
done

[[ -f "$ROOT/pipeline/source/metadata.json" ]] \
  || fail "nested English tree missing at pipeline/source (run: make submodules)"
[[ -f "$ROOT/pipeline/langs/spanish/metadata.json" ]] \
  || fail "nested Spanish tree missing at pipeline/langs/spanish (run: make submodules)"

echo "submodules: hub, api, pipeline, and data-sources track main via relative URLs"
