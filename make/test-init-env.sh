#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

cat >"$tmp" <<EOF
COMPOSE_PROJECT_NAME=urantialab
UKLOK_ROOT=/tmp/fake-uklok
PIPELINE_ROOT=/tmp/fake-uklok/URANTIA
API_ROOT=/tmp/fake-uklok/urantia-dev-api
HUB_ROOT=/tmp/fake-uklok/urantia-hub
BOOK_TREE=/tmp/fake-uklok/URANTIA/source
POSTGRES_USER=urantia
POSTGRES_PASSWORD=testpass
POSTGRES_DB=papers
HUB_DB=hub
REDIS_PASSWORD=testredis
NEXTAUTH_SECRET=testsecret
POSTGRES_HOST_PORT=5433
REDIS_HOST_PORT=6380
API_HOST_PORT=3000
HUB_HOST_PORT=3001
EOF

SHARED_ENV_FILE="$tmp" "$ROOT/make/init-env.sh" >/dev/null

grep -q '^UKLOK_ROOT=' "$tmp" && fail "init must drop leftover UKLOK_ROOT"
grep -qx "PIPELINE_ROOT=$ROOT/pipeline" "$tmp" || fail "PIPELINE_ROOT must be the in-repo pipeline submodule"
grep -qx "API_ROOT=$ROOT/api" "$tmp" || fail "API_ROOT must be the in-repo api submodule"
grep -qx "HUB_ROOT=$ROOT/hub" "$tmp" || fail "HUB_ROOT must be the in-repo hub submodule"
grep -qx "DATA_SOURCES_ROOT=$ROOT/data-sources" "$tmp" || fail "DATA_SOURCES_ROOT must be the in-repo data-sources submodule"
grep -qx "BOOK_TREE=$ROOT/pipeline/source" "$tmp" || fail "BOOK_TREE must be pipeline/source"

echo "init-env: leftover sibling paths restamp onto in-repo checkouts"
