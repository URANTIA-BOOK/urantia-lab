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
done

echo "submodules: hub, api, pipeline, and data-sources track main via relative URLs"
