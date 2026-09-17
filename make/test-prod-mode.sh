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

echo "prod-mode: hub and API production images, data-only binds"
