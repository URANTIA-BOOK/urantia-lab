#!/usr/bin/env bash
# Stamp public hub/API origins from EDGE_PUBLIC_URL + CADDY_API_PATH.
# Browser traffic uses the published edge; hub SSR stays on
# URANTIA_DEV_API_INTERNAL_HOST=http://api:3000 (Compose, not this file).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=env-utils.sh
source "$SCRIPT_DIR/env-utils.sh"

SHARED_ENV_FILE="${SHARED_ENV_FILE:-$REPOSITORY_ROOT/.env.shared}"

env_has_key() {
  local env_file="$1"
  local key="$2"
  grep -q "^${key}=" "$env_file" 2>/dev/null
}

strip_origin() {
  local origin="$1"
  printf '%s' "${origin%/}"
}

join_origin_path() {
  local origin="$1"
  local path="$2"
  origin="$(strip_origin "$origin")"
  path="/${path#/}"
  path="${path%/}"
  printf '%s%s' "$origin" "$path"
}

valid_origin() {
  local url="$1"
  [[ -n "$url" ]] || return 1
  [[ "$url" =~ ^https?://[^[:space:]]+$ ]]
}

stamp_file() {
  local env_file="$1"
  local origin="$2"
  local api_url="$3"

  if env_has_key "$env_file" HUB_PUBLIC_URL; then
    set_env_value "$env_file" HUB_PUBLIC_URL "$origin"
  fi
  if env_has_key "$env_file" NEXT_PUBLIC_HOST; then
    set_env_value "$env_file" NEXT_PUBLIC_HOST "$origin"
  fi
  if env_has_key "$env_file" NEXTAUTH_URL; then
    set_env_value "$env_file" NEXTAUTH_URL "$origin"
  fi
  if env_has_key "$env_file" API_PUBLIC_URL; then
    set_env_value "$env_file" API_PUBLIC_URL "$api_url"
  fi
  if env_has_key "$env_file" NEXT_PUBLIC_URANTIA_DEV_API_HOST; then
    set_env_value "$env_file" NEXT_PUBLIC_URANTIA_DEV_API_HOST "$api_url"
  fi
}

origin="$(strip_origin "$(read_env_value "$SHARED_ENV_FILE" EDGE_PUBLIC_URL)")"
if [[ -z "$origin" ]]; then
  exit 0
fi

if ! valid_origin "$origin"; then
  echo "EDGE_PUBLIC_URL must be a non-empty http:// or https:// URL: $origin" >&2
  exit 1
fi

api_path="$(read_env_value "$SHARED_ENV_FILE" CADDY_API_PATH)"
api_path="${api_path:-/dev-api}"
api_url="$(join_origin_path "$origin" "$api_path")"

targets=("$SHARED_ENV_FILE")
for env_file in "$@"; do
  [[ -f "$env_file" ]] || continue
  targets+=("$env_file")
done

for env_file in "${targets[@]}"; do
  [[ -f "$env_file" ]] || continue
  stamp_file "$env_file" "$origin" "$api_url"
done
