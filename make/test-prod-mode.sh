#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

grep -q 'yarn build && yarn start' "$ROOT/stack/hub/docker-compose.yml" \
  || fail "hub production compose must build and yarn start"
grep -q 'NODE_ENV: production' "$ROOT/stack/hub/docker-compose.yml" \
  || fail "hub production compose must set NODE_ENV=production"
grep -q 'yarn dev' "$ROOT/stack/hub/docker-compose.dev.yml" \
  || fail "hub dev overlay must run yarn dev"

grep -q 'bun run start' "$ROOT/stack/api/docker-compose.yml" \
  || fail "api production compose must bun run start"
grep -q 'NODE_ENV: production' "$ROOT/stack/api/docker-compose.yml" \
  || fail "api production compose must set NODE_ENV=production"
grep -q 'bun run dev' "$ROOT/stack/api/docker-compose.dev.yml" \
  || fail "api dev overlay must run bun run dev"

if grep -q 'yarn dev' "$ROOT/stack/hub/docker-compose.yml"; then
  fail "hub production compose must not run yarn dev"
fi
if grep -q 'bun run dev' "$ROOT/stack/api/docker-compose.yml"; then
  fail "api production compose must not run bun --hot / bun run dev"
fi

echo "prod-mode: hub and API production commands are in the base compose"
