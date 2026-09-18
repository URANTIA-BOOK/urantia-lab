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
grep -qx "EDGE_PUBLIC_URL=http://localhost:8080" "$tmp" || fail "fresh/empty origin must default to localhost"
grep -qx "EDGE_HOSTNAME=localhost" "$tmp" || fail "EDGE_HOSTNAME must be derived from the origin"
grep -qx "CADDY_API_PATH=/dev-api" "$tmp" || fail "CADDY_API_PATH must default to /dev-api"
grep -qx "API_PUBLIC_URL=http://localhost:8080/dev-api" "$tmp" || fail "API_PUBLIC_URL must be origin + CADDY_API_PATH"
grep -qx "HUB_PUBLIC_URL=http://localhost:8080" "$tmp" || fail "HUB_PUBLIC_URL must follow the published origin"

kept="$(mktemp)"
trap 'rm -f "$tmp" "$kept"' EXIT
cat >"$kept" <<EOF
COMPOSE_PROJECT_NAME=urantialab
EDGE_PUBLIC_URL=https://urantia.uklok.cloud
CADDY_API_PATH=/dev-api
POSTGRES_USER=urantia
POSTGRES_PASSWORD=testpass
POSTGRES_DB=papers
HUB_DB=hub
REDIS_PASSWORD=testredis
NEXTAUTH_SECRET=testsecret
POSTGRES_HOST_PORT=5433
REDIS_HOST_PORT=6380
HUB_PUBLIC_URL=https://old.example
API_PUBLIC_URL=https://old.example/api
EOF
SHARED_ENV_FILE="$kept" "$ROOT/make/init-env.sh" >/dev/null
grep -qx "EDGE_PUBLIC_URL=https://urantia.uklok.cloud" "$kept" \
  || fail "existing EDGE_PUBLIC_URL must be kept on non-TTY re-init"
grep -qx "HUB_PUBLIC_URL=https://urantia.uklok.cloud" "$kept" \
  || fail "existing origin must restamp derived hub URL"
grep -qx "EDGE_HOSTNAME=urantia.uklok.cloud" "$kept" \
  || fail "existing origin must derive EDGE_HOSTNAME"

CADDY_API_PATH=/v1 EDGE_PUBLIC_URL=http://localhost:8080 \
  SHARED_ENV_FILE="$tmp" "$ROOT/make/init-env.sh" >/dev/null
grep -qx "CADDY_API_PATH=/v1" "$tmp" || fail "CADDY_API_PATH env must win"
grep -qx "API_PUBLIC_URL=http://localhost:8080/v1" "$tmp" \
  || fail "API_PUBLIC_URL must follow CADDY_API_PATH"

HTTP_PORT=9090 \
  SHARED_ENV_FILE="$tmp" "$ROOT/make/init-env.sh" >/dev/null
grep -qx "CADDY_HTTP_PORT=9090" "$tmp" || fail "HTTP_PORT must stamp CADDY_HTTP_PORT"
grep -qx "EDGE_PUBLIC_URL=http://localhost:9090" "$tmp" \
  || fail "localhost origin must follow HTTP_PORT overwrite"

HTTP_PORT=9090 EDGE_PUBLIC_URL=https://urantia.uklok.cloud \
  SHARED_ENV_FILE="$kept" "$ROOT/make/init-env.sh" >/dev/null
grep -qx "CADDY_HTTP_PORT=9090" "$kept" || fail "HTTP_PORT must stamp a public copy's bind port"
grep -qx "EDGE_PUBLIC_URL=https://urantia.uklok.cloud" "$kept" \
  || fail "public origin must stay when only the bind port changes"

make_port="$(printf 'probe:\n\t@printf %%s "$$HTTP_PORT"\n' \
  | make -f "$ROOT/make/project.mk" -f - HTTP_PORT=9090 probe)"
[[ "$make_port" == "9090" ]] || fail "make HTTP_PORT=9090 must reach recipes (got '$make_port')"

up_n="$(make -C "$ROOT" -n --no-print-directory up)"
echo "$up_n" | grep -q test-edge-origin && fail "make up must not run the contract tests"
echo "$up_n" | grep -q init-env.sh || fail "make up must still restamp via init"
validate_n="$(make -C "$ROOT" -n --no-print-directory validate)"
echo "$validate_n" | grep -q test-edge-origin || fail "make validate must run the contract tests"

echo "init-env: leftover sibling paths restamp onto in-repo checkouts"
