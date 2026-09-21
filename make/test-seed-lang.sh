#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PIPELINE="$ROOT/pipeline"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

help="$(make -C "$ROOT" -s help)"
printf '%s\n' "$help" | grep -q 'seed-lang KEY=' \
  || fail "make help must mention make seed-lang KEY="

dry="$(make -C "$ROOT" -n seed-lang KEY=ger)"
printf '%s\n' "$dry" | grep -q 'submodule update' \
  && fail "seed-lang KEY=ger must not git submodule update (that registered langs/arabic)"
printf '%s\n' "$dry" | grep -q 'seed.sh' \
  || fail "seed-lang KEY=ger must still run make/seed.sh"

if make -C "$ROOT" seed-lang >/dev/null 2>&1; then
  fail "seed-lang without L or KEY should fail"
fi

py="$PIPELINE/.venv/bin/python3"
[[ -x "$py" ]] || py="python3"

lookup() {
  "$py" "$PIPELINE/scripts/lang_pipeline.py" lookup --lang "$1"
}

cze="$(lookup cze)" || fail "lookup --lang cze"
printf '%s\n' "$cze" | grep -qx 'key=cze' || fail "cze key"
printf '%s\n' "$cze" | grep -qx 'repo=czech' || fail "cze repo"
printf '%s\n' "$cze" | grep -qx 'tree=langs/czech' || fail "cze tree"

spa="$(lookup spa_int)" || fail "lookup --lang spa_int"
printf '%s\n' "$spa" | grep -qx 'key=spa_int' || fail "spa_int key"
printf '%s\n' "$spa" | grep -qx 'repo=spanish_int' || fail "spa_int repo"

if lookup no_such_lang >/dev/null 2>&1; then
  fail "unknown registry key should fail"
fi

grep -q 'extra\[@\]' "$ROOT/make/seed.sh" \
  && fail "seed.sh must not expand extra[@] (set -u dies when KEY= has no L=)"

echo "seed-lang: registry lookup KEY=cze → langs/czech; KEY=spa_int → langs/spanish_int"
