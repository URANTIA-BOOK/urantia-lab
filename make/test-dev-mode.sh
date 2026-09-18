#!/usr/bin/env bash
# MODE=dev is the overlay door. Prod publishes Caddy only. Diagnostic host
# ports live on docker-compose.dev.yml and interpolate from .env.shared.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

grep -q 'ports:' "$ROOT/stack/db/postgres/docker-compose.yml" \
  && fail "postgres production compose must not publish host ports"
grep -q '${POSTGRES_HOST_PORT' "$ROOT/stack/db/postgres/docker-compose.dev.yml" \
  || fail "postgres dev overlay must publish POSTGRES_HOST_PORT from shared"
grep -q 'apps:' "$ROOT/stack/db/postgres/docker-compose.dev.yml" \
  || fail "postgres dev overlay must join apps so the host port can bind"
grep -q '${REDIS_HOST_PORT' "$ROOT/stack/redis/docker-compose.dev.yml" \
  || fail "redis dev overlay must publish REDIS_HOST_PORT from shared"
grep -q 'apps:' "$ROOT/stack/redis/docker-compose.dev.yml" \
  || fail "redis dev overlay must join apps so the host port can bind"
grep -q '${API_HOST_PORT' "$ROOT/stack/api/docker-compose.dev.yml" \
  || fail "api dev overlay must publish API_HOST_PORT from shared"
grep -q '${HUB_HOST_PORT' "$ROOT/stack/hub/docker-compose.dev.yml" \
  || fail "hub dev overlay must publish HUB_HOST_PORT from shared"

grep -q '^dev-up:' "$ROOT/Makefile" || fail "root Makefile must have make dev-up"
grep -q '^dev-down:' "$ROOT/Makefile" || fail "root Makefile must have make dev-down"

if grep -q 'CADDY_HTTP_PORT=$(or' "$ROOT/make/compose.mk"; then
  fail "compose.mk must not pin CADDY_HTTP_PORT on COMPOSE :="
fi
if grep -q 'CADDY_HTTP_PORT_FILE' "$ROOT/make/project.mk"; then
  fail "project.mk must not re-read CADDY_HTTP_PORT from the shared file"
fi
if grep -q '^CADDY_HTTP_PORT=' "$ROOT/stack/edge/.env.example"; then
  fail "stack/edge/.env.example must not own CADDY_HTTP_PORT"
fi
if grep -q '^EDGE_PUBLIC_URL=' "$ROOT/stack/edge/.env.example"; then
  fail "stack/edge/.env.example must not own EDGE_PUBLIC_URL"
fi

dev_n="$(make -C "$ROOT/stack/db/postgres" -n --no-print-directory config MODE=dev)"
echo "$dev_n" | grep -q 'docker-compose.dev.yml' \
  || fail "make -C stack/db/postgres config MODE=dev must apply docker-compose.dev.yml"
prod_n="$(make -C "$ROOT/stack/db/postgres" -n --no-print-directory config MODE=prod)"
echo "$prod_n" | grep -q 'docker-compose.dev.yml' \
  && fail "make -C stack/db/postgres config MODE=prod must not apply the dev overlay"

root_n="$(make -C "$ROOT" -n --no-print-directory postgres-up MODE=dev)"
echo "$root_n" | grep -q 'MODE=dev' \
  || fail "make postgres-up MODE=dev must pass MODE=dev to the stack"

if [[ -f "$ROOT/.env.shared" ]] && command -v docker >/dev/null; then
  expected="$(sed -n 's/^POSTGRES_HOST_PORT=//p' "$ROOT/.env.shared" | tail -n 1)"
  expected="${expected:-5433}"
  published="$(make -C "$ROOT/stack/db/postgres" MODE=dev config \
    | awk '/published:/{gsub(/"/,""); print $2; exit}')" \
    || fail "MODE=dev postgres compose config failed"
  [[ "$published" == "$expected" ]] \
    || fail "MODE=dev postgres compose must publish shared POSTGRES_HOST_PORT $expected (got '$published')"
  if make -C "$ROOT/stack/db/postgres" MODE=prod config | grep -q 'published:'; then
    fail "MODE=prod postgres compose must not publish host ports"
  fi
fi

echo "dev-mode: overlay publishes diagnostic ports from .env.shared"
