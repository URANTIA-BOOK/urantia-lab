#!/usr/bin/env bash
# Derive public hub/API origins from EDGE_PUBLIC_URL + CADDY_API_PATH.
# .env.shared is the only identity file. Stack .env files keep only the
# keys they already own (Wealth stamp-app-urls). Compose interpolates
# CADDY_HTTP_PORT and diagnostic host ports from --env-file .env.shared.
# A localhost / 127.0.0.1 origin follows CADDY_HTTP_PORT. A public host
# does not (the bind port is the tunnel target, not the browser origin).
# Hub SSR stays on URANTIA_DEV_API_INTERNAL_HOST=http://api:3000.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=env-utils.sh
source "$SCRIPT_DIR/env-utils.sh"
# shellcheck source=edge-origin.sh
source "$SCRIPT_DIR/edge-origin.sh"

SHARED_ENV_FILE="${SHARED_ENV_FILE:-$REPOSITORY_ROOT/.env.shared}"

# Keys that live on .env.shared. A stack .env must not grow a second copy.
SHARED_IDENTITY_KEYS=(
  EDGE_PUBLIC_URL
  HUB_PUBLIC_URL
  NEXT_PUBLIC_HOST
  NEXTAUTH_URL
  API_PUBLIC_URL
  NEXT_PUBLIC_URANTIA_DEV_API_HOST
  EDGE_HOSTNAME
  EDGE_FORWARDED_PROTO
  CADDY_HOST_MATCHERS
  CADDY_HTTP_PORT
  CADDY_API_PATH
  POSTGRES_HOST_PORT
  REDIS_HOST_PORT
  API_HOST_PORT
  HUB_HOST_PORT
)

env_has_key() {
  local env_file="$1"
  local key="$2"
  grep -q "^${key}=" "$env_file" 2>/dev/null
}

same_file() {
  local left="$1"
  local right="$2"
  [[ -f "$left" && -f "$right" ]] || return 1
  [[ "$(realpath "$left")" == "$(realpath "$right")" ]]
}

strip_origin() {
  local origin="$1"
  printf '%s' "${origin%/}"
}

join_origin_path() {
  local origin="$1"
  local path="$2"
  origin="$(strip_origin "$origin")"
  path="$(normalize_api_path "$path")"
  printf '%s%s' "$origin" "$path"
}

valid_origin() {
  local url="$1"
  [[ -n "$url" ]] || return 1
  [[ "$url" =~ ^https?://[^[:space:]]+$ ]]
}

write_derived() {
  local env_file="$1"
  local origin="$2"
  local api_url="$3"
  local hostname="$4"
  local proto="$5"
  local hosts="$6"

  set_env_value "$env_file" EDGE_PUBLIC_URL "$origin"
  set_env_value "$env_file" HUB_PUBLIC_URL "$origin"
  set_env_value "$env_file" NEXT_PUBLIC_HOST "$origin"
  set_env_value "$env_file" NEXTAUTH_URL "$origin"
  set_env_value "$env_file" API_PUBLIC_URL "$api_url"
  set_env_value "$env_file" NEXT_PUBLIC_URANTIA_DEV_API_HOST "$api_url"
  set_env_value "$env_file" EDGE_HOSTNAME "$hostname"
  set_env_value "$env_file" EDGE_FORWARDED_PROTO "$proto"
  set_env_value "$env_file" CADDY_HOST_MATCHERS "$hosts"
  set_env_value "$env_file" CADDY_HTTP_PORT "$caddy_port"
  set_env_value "$env_file" CADDY_API_PATH "$(normalize_api_path "$(read_env_value "$SHARED_ENV_FILE" CADDY_API_PATH)")"
}

stamp_owned_keys() {
  local env_file="$1"
  local origin="$2"
  local api_url="$3"
  local hostname="$4"
  local proto="$5"
  local hosts="$6"
  local example
  example="$(dirname "$env_file")/.env.example"

  if [[ -f "$example" ]]; then
    for key in "${SHARED_IDENTITY_KEYS[@]}"; do
      if env_has_key "$env_file" "$key" && ! env_has_key "$example" "$key"; then
        unset_env_value "$env_file" "$key"
      fi
    done
  fi

  if env_has_key "$env_file" EDGE_PUBLIC_URL; then
    set_env_value "$env_file" EDGE_PUBLIC_URL "$origin"
  fi
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
  if env_has_key "$env_file" EDGE_HOSTNAME; then
    set_env_value "$env_file" EDGE_HOSTNAME "$hostname"
  fi
  if env_has_key "$env_file" EDGE_FORWARDED_PROTO; then
    set_env_value "$env_file" EDGE_FORWARDED_PROTO "$proto"
  fi
  if env_has_key "$env_file" CADDY_HOST_MATCHERS; then
    set_env_value "$env_file" CADDY_HOST_MATCHERS "$hosts"
  fi
  if env_has_key "$env_file" CADDY_HTTP_PORT; then
    set_env_value "$env_file" CADDY_HTTP_PORT "$caddy_port"
  fi
  if env_has_key "$env_file" CADDY_API_PATH; then
    set_env_value "$env_file" CADDY_API_PATH "$(normalize_api_path "$(read_env_value "$SHARED_ENV_FILE" CADDY_API_PATH)")"
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

hostname="$(origin_hostname "$origin")"
[[ -n "$hostname" ]] || hostname="$DEFAULT_EDGE_HOSTNAME"
caddy_port="$(read_env_value "$SHARED_ENV_FILE" CADDY_HTTP_PORT)"
if valid_http_port "$caddy_port" && { [[ "$hostname" == "localhost" ]] || [[ "$hostname" == "127.0.0.1" ]]; }; then
  origin="$(derive_edge_public_url "$hostname" "$caddy_port")"
fi

api_path="$(normalize_api_path "$(read_env_value "$SHARED_ENV_FILE" CADDY_API_PATH)")"
api_url="$(join_origin_path "$origin" "$api_path")"
proto="$(origin_scheme "$origin")"
[[ -n "$caddy_port" ]] || caddy_port="$DEFAULT_CADDY_HTTP_PORT"
hosts="$(caddy_host_matchers "$hostname" "$caddy_port")"

targets=("$SHARED_ENV_FILE")
for env_file in "$@"; do
  [[ -f "$env_file" ]] || continue
  targets+=("$env_file")
done

for env_file in "${targets[@]}"; do
  [[ -f "$env_file" ]] || continue
  if same_file "$env_file" "$SHARED_ENV_FILE"; then
    write_derived "$env_file" "$origin" "$api_url" "$hostname" "$proto" "$hosts"
  else
    stamp_owned_keys "$env_file" "$origin" "$api_url" "$hostname" "$proto" "$hosts"
  fi
done
