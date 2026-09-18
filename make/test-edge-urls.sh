#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env-utils.sh
source "$SCRIPT_DIR/env-utils.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local description="$3"
  [[ "$actual" == "$expected" ]] || fail "$description (got '$actual', expected '$expected')"
}

stamp_dir="$(mktemp -d)"
trap 'rm -rf "$stamp_dir"' EXIT

write_shared() {
  cat >"$stamp_dir/.env.shared" <<EOF
HUB_PUBLIC_URL=http://127.0.0.1:3001
API_PUBLIC_URL=http://127.0.0.1:3000
NEXT_PUBLIC_URANTIA_DEV_API_HOST=http://127.0.0.1:3000
NEXT_PUBLIC_HOST=http://127.0.0.1:3001
NEXTAUTH_URL=http://127.0.0.1:3001
CADDY_HTTP_PORT=8080
CADDY_API_PATH=/dev-api
EDGE_PUBLIC_URL=$1
EOF
}

run_stamp() {
  SHARED_ENV_FILE="$stamp_dir/.env.shared" "$SCRIPT_DIR/stamp-edge-urls.sh" "$@"
}

write_shared 'http://localhost:8080'
run_stamp
assert_eq "$(read_env_value "$stamp_dir/.env.shared" HUB_PUBLIC_URL)" 'http://localhost:8080' "local hub origin"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" NEXT_PUBLIC_HOST)" 'http://localhost:8080' "local NEXT_PUBLIC_HOST"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" NEXTAUTH_URL)" 'http://localhost:8080' "local NEXTAUTH_URL"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" API_PUBLIC_URL)" 'http://localhost:8080/dev-api' "local API under /dev-api"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" NEXT_PUBLIC_URANTIA_DEV_API_HOST)" 'http://localhost:8080/dev-api' "local browser API host"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" EDGE_HOSTNAME)" 'localhost' "local EDGE_HOSTNAME"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" EDGE_FORWARDED_PROTO)" 'http' "local forwarded proto"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" CADDY_HOST_MATCHERS)" \
  'localhost 127.0.0.1 localhost:8080 127.0.0.1:8080' \
  "localhost host list must not repeat localhost"

write_shared 'http://localhost:8080'
set_env_value "$stamp_dir/.env.shared" CADDY_HTTP_PORT 9080
run_stamp
assert_eq "$(read_env_value "$stamp_dir/.env.shared" EDGE_PUBLIC_URL)" 'http://localhost:9080' "localhost origin follows CADDY_HTTP_PORT"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" HUB_PUBLIC_URL)" 'http://localhost:9080' "localhost hub follows CADDY_HTTP_PORT"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" API_PUBLIC_URL)" 'http://localhost:9080/dev-api' "localhost API follows CADDY_HTTP_PORT"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" CADDY_HOST_MATCHERS)" \
  'localhost 127.0.0.1 localhost:9080 127.0.0.1:9080' \
  "localhost host list follows the bind port once"

write_shared 'https://urantia.uklok.cloud'
set_env_value "$stamp_dir/.env.shared" CADDY_HTTP_PORT 9080
run_stamp
assert_eq "$(read_env_value "$stamp_dir/.env.shared" EDGE_PUBLIC_URL)" 'https://urantia.uklok.cloud' "public origin ignores bind port"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" HUB_PUBLIC_URL)" 'https://urantia.uklok.cloud' "public hub ignores bind port"

write_shared 'https://urantia.uklok.cloud/'
run_stamp
assert_eq "$(read_env_value "$stamp_dir/.env.shared" HUB_PUBLIC_URL)" 'https://urantia.uklok.cloud' "public hub strips trailing slash"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" API_PUBLIC_URL)" 'https://urantia.uklok.cloud/dev-api' "public API has no double slash"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" NEXT_PUBLIC_URANTIA_DEV_API_HOST)" 'https://urantia.uklok.cloud/dev-api' "public browser API host"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" EDGE_HOSTNAME)" 'urantia.uklok.cloud' "public EDGE_HOSTNAME"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" EDGE_FORWARDED_PROTO)" 'https' "public forwarded proto"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" CADDY_HOST_MATCHERS)" \
  'urantia.uklok.cloud localhost 127.0.0.1 urantia.uklok.cloud:8080 localhost:8080 127.0.0.1:8080' \
  "public host list keeps loopback without repeating the public name"

write_shared 'https://urantia.uklok.cloud'
printf 'CADDY_API_PATH=/v1\n' >>"$stamp_dir/.env.shared"
run_stamp
assert_eq "$(read_env_value "$stamp_dir/.env.shared" API_PUBLIC_URL)" 'https://urantia.uklok.cloud/v1' "custom CADDY_API_PATH"

write_shared 'https://urantia.uklok.cloud'
set_env_value "$stamp_dir/.env.shared" CADDY_HTTP_PORT 9180
stack_dir="$stamp_dir/stack"
mkdir -p "$stack_dir"
printf 'COMPOSE_PROJECT_NAME=urantialab\n' >"$stack_dir/.env.example"
printf 'COMPOSE_PROJECT_NAME=urantialab\nCADDY_HTTP_PORT=8080\nHUB_PUBLIC_URL=http://example.invalid\nAPI_PUBLIC_URL=http://example.invalid\nIGNORED=keep\n' >"$stack_dir/.env"
run_stamp "$stack_dir/.env"
assert_eq "$(read_env_value "$stack_dir/.env" IGNORED)" 'keep' "unrelated stack keys stay"
assert_eq "$(read_env_value "$stack_dir/.env" COMPOSE_PROJECT_NAME)" 'urantialab' "stack Compose name stays"
assert_eq "$(read_env_value "$stack_dir/.env" CADDY_HTTP_PORT)" '' \
  "stack .env must not keep a second CADDY_HTTP_PORT"
assert_eq "$(read_env_value "$stack_dir/.env" HUB_PUBLIC_URL)" '' \
  "stack .env must not keep a second HUB_PUBLIC_URL"
assert_eq "$(read_env_value "$stack_dir/.env" API_PUBLIC_URL)" '' \
  "stack .env must not keep a second API_PUBLIC_URL"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" CADDY_HTTP_PORT)" '9180' \
  "shared keeps the bind port"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" API_PUBLIC_URL)" 'https://urantia.uklok.cloud/dev-api' \
  "shared keeps the derived API origin"

owned_dir="$stamp_dir/owned"
mkdir -p "$owned_dir"
printf 'API_PUBLIC_URL=\n' >"$owned_dir/.env.example"
printf 'API_PUBLIC_URL=http://example.invalid\n' >"$owned_dir/.env"
run_stamp "$owned_dir/.env"
assert_eq "$(read_env_value "$owned_dir/.env" API_PUBLIC_URL)" 'https://urantia.uklok.cloud/dev-api' \
  "a file whose example owns API_PUBLIC_URL is stamped"

write_shared ''
printf 'HUB_PUBLIC_URL=http://127.0.0.1:3001\nAPI_PUBLIC_URL=http://127.0.0.1:3000\n' >"$stamp_dir/.env.shared"
run_stamp
assert_eq "$(read_env_value "$stamp_dir/.env.shared" HUB_PUBLIC_URL)" 'http://127.0.0.1:3001' "empty EDGE_PUBLIC_URL is a no-op"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" API_PUBLIC_URL)" 'http://127.0.0.1:3000' "empty EDGE_PUBLIC_URL leaves API host"

echo "Edge URL stamp helpers are consistent."
