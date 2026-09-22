#!/usr/bin/env bash
# make seed follows langs-status `built`, not a fixed overlay list.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PIPELINE="$ROOT/pipeline"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

help="$(make -C "$ROOT" -s help)"
printf '%s\n' "$help" | grep -q 'langs-status marks built' \
  || fail "make help must say make seed follows langs-status"

grep -q '</dev/null' "$ROOT/make/seed.sh" \
  || fail "compose exec must not read the langs-status loop on stdin"

# shellcheck source=seed.sh
source "$ROOT/make/seed.sh"

fixture="$(printf '%s\n' \
  '  key       repo          parent      raw     built br  tag' \
  '  cze       czech         source      yes     no    —   —' \
  '  nld       dutch         source      missing yes   2   UF-NLD' \
  '  ara       arabic        source      missing no    —   —' \
  | parse_langs_status)"

printf '%s\n' "$fixture" | grep -qx $'nld\tdutch\tyes' \
  || fail "parser must keep a built row even when raw is missing"
printf '%s\n' "$fixture" | grep -q $'cze\tczech\tno' \
  || fail "parser must keep an unbuilt row so seed can skip it"
printf '%s\n' "$fixture" | grep -q $'cze\tczech\tyes' \
  && fail "parser must not treat the raw column as built"
printf '%s\n' "$fixture" | grep -q $'^ara\t' \
  || fail "parser dropped arabic"

rows="$(langs_status_rows)"
[[ -n "$rows" ]] || fail "langs-status returned no edition rows"

python3 - "$PIPELINE" "$rows" <<'PY'
import json, sys
from pathlib import Path

pipeline = Path(sys.argv[1])
rows = [line.split("\t") for line in sys.argv[2].splitlines() if line]
got = {(key, repo): built for key, repo, built in rows}
reg = json.loads((pipeline / "langs" / "registry.json").read_text())
expect = {}
for lang in reg["languages"]:
    tree = pipeline / "source" if lang.get("base") else pipeline / "langs" / lang["repo"]
    built = "yes" if (tree / ".git").exists() else "no"
    expect[(lang["key"], lang["repo"])] = built
if got != expect:
    missing = sorted(set(expect) - set(got))
    extra = sorted(set(got) - set(expect))
    differ = sorted(k for k in set(got) & set(expect) if got[k] != expect[k])
    raise SystemExit(
        f"langs-status parse != registry .git state\n missing={missing}\n extra={extra}\n differ={differ}"
    )
built = sorted(repo for (_key, repo), flag in got.items() if flag == "yes")
if "source" not in built:
    raise SystemExit("English source must be built")
print("built:", " ".join(built))
PY

echo "seed: make seed follows langs-status built editions"
