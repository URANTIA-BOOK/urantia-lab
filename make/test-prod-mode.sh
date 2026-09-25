#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

grep -q 'yarn start' "$ROOT/hub/Dockerfile" \
  || fail "hub Dockerfile must yarn start"
grep -q 'NODE_ENV: production' "$ROOT/stack/hub/docker-compose.yml" \
  || fail "hub production compose must set NODE_ENV=production"
grep -q 'dockerfile: Dockerfile' "$ROOT/stack/hub/docker-compose.yml" \
  || fail "hub production compose must build the module Dockerfile"
grep -q 'yarn dev' "$ROOT/stack/hub/docker-compose.dev.yml" \
  || fail "hub dev overlay must run yarn dev"

if grep -q '${HUB_ROOT}:/app' "$ROOT/stack/hub/docker-compose.yml"; then
  fail "hub production compose must not bind-mount hub source"
fi
if grep -q 'yarn dev' "$ROOT/stack/hub/docker-compose.yml"; then
  fail "hub production compose must not run yarn dev"
fi
grep -q -- '- backend' "$ROOT/stack/hub/docker-compose.yml" \
  || fail "hub must join backend for its PostgreSQL and Redis dependencies"
grep -q 'DATABASE_URL: ${HUB_DATABASE_URL}' "$ROOT/stack/hub/docker-compose.yml" \
  || fail "hub must receive its own database as DATABASE_URL"
grep -q 'REDIS_URL: ${REDIS_URL}' "$ROOT/stack/hub/docker-compose.yml" \
  || fail "hub must receive REDIS_URL"
grep -q 'PAPERS_DATABASE_URL: ""' "$ROOT/stack/hub/docker-compose.yml" \
  || fail "hub must not receive the papers database credential"
grep -q 'URANTIA_DEV_API_INTERNAL_HOST: http://api:3000' "$ROOT/stack/hub/docker-compose.yml" \
  || fail "hub SSR must call the API on apps"
if grep -q 'command: \["yarn", "start"\]' "$ROOT/stack/hub/docker-compose.yml"; then
  fail "hub compose must keep the image migration-first command"
fi
grep -q 'prisma migrate deploy.*exec yarn start' "$ROOT/hub/Dockerfile" \
  || fail "hub image must migrate before Next.js startup"

if grep -q 'apps:' "$ROOT/stack/db/postgres/docker-compose.yml"; then
  fail "postgres production compose must not join apps"
fi
if grep -q 'apps:' "$ROOT/stack/redis/docker-compose.yml"; then
  fail "redis production compose must not join apps"
fi
grep -q -- '- backend' "$ROOT/stack/api/docker-compose.yml" \
  || fail "api must join backend (papers adapter)"
grep -q -- '- apps' "$ROOT/stack/api/docker-compose.yml" \
  || fail "api must join apps (papers adapter)"

grep -q 'bun.*start' "$ROOT/api/Dockerfile" \
  || fail "api Dockerfile must bun start"
grep -q 'NODE_ENV: production' "$ROOT/stack/api/docker-compose.yml" \
  || fail "api production compose must set NODE_ENV=production"
grep -q 'dockerfile: Dockerfile' "$ROOT/stack/api/docker-compose.yml" \
  || fail "api production compose must build the module Dockerfile"
grep -q '/book/eng' "$ROOT/stack/api/docker-compose.yml" \
  || fail "api production compose must bind the English book tree"
grep -q 'bun run dev' "$ROOT/stack/api/docker-compose.dev.yml" \
  || fail "api dev overlay must run bun run dev"

if grep -q '${API_ROOT}:/app' "$ROOT/stack/api/docker-compose.yml"; then
  fail "api production compose must not bind-mount API source"
fi
if grep -q 'bun run dev' "$ROOT/stack/api/docker-compose.yml"; then
  fail "api production compose must not run bun --hot / bun run dev"
fi

grep -q '`hub` joins both `apps` and `backend`' "$ROOT/.agents/skills/stack-networks/SKILL.md" \
  || fail "stack-networks skill must record Hub dual-plane ownership"
grep -q 'postgres` and `redis` join `backend` only' "$ROOT/.agents/skills/stack-networks/SKILL.md" \
  || fail "stack-networks skill must keep postgres and redis on backend"

echo "prod-mode: Hub runtime dependencies, production images, data-only binds, network planes"
