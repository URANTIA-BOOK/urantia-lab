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

write_shared 'https://urantia.uklok.cloud/'
run_stamp
assert_eq "$(read_env_value "$stamp_dir/.env.shared" HUB_PUBLIC_URL)" 'https://urantia.uklok.cloud' "public hub strips trailing slash"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" API_PUBLIC_URL)" 'https://urantia.uklok.cloud/dev-api' "public API has no double slash"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" NEXT_PUBLIC_URANTIA_DEV_API_HOST)" 'https://urantia.uklok.cloud/dev-api' "public browser API host"

write_shared 'https://urantia.uklok.cloud'
printf 'CADDY_API_PATH=/v1\n' >>"$stamp_dir/.env.shared"
run_stamp
assert_eq "$(read_env_value "$stamp_dir/.env.shared" API_PUBLIC_URL)" 'https://urantia.uklok.cloud/v1' "custom CADDY_API_PATH"

cat >"$stamp_dir/extra.env" <<'EOF'
API_PUBLIC_URL=http://example.invalid
IGNORED=keep
EOF
write_shared 'https://urantia.uklok.cloud'
run_stamp "$stamp_dir/extra.env"
assert_eq "$(read_env_value "$stamp_dir/extra.env" API_PUBLIC_URL)" 'https://urantia.uklok.cloud/dev-api' "extra file with API_PUBLIC_URL is stamped"
assert_eq "$(read_env_value "$stamp_dir/extra.env" IGNORED)" 'keep' "unrelated extra keys stay"

write_shared ''
printf 'HUB_PUBLIC_URL=http://127.0.0.1:3001\nAPI_PUBLIC_URL=http://127.0.0.1:3000\n' >"$stamp_dir/.env.shared"
run_stamp
assert_eq "$(read_env_value "$stamp_dir/.env.shared" HUB_PUBLIC_URL)" 'http://127.0.0.1:3001' "empty EDGE_PUBLIC_URL is a no-op"
assert_eq "$(read_env_value "$stamp_dir/.env.shared" API_PUBLIC_URL)" 'http://127.0.0.1:3000' "empty EDGE_PUBLIC_URL leaves API host"

echo "Edge URL stamp helpers are consistent."
