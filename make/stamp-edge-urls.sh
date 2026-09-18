#!/usr/bin/env bash
# Stamp public hub/API origins from EDGE_PUBLIC_URL + CADDY_API_PATH.
# A localhost / 127.0.0.1 origin follows CADDY_HTTP_PORT. A public host
# does not (the bind port is the tunnel target, not the browser origin).
# Browser traffic uses the published edge; hub SSR stays on
# URANTIA_DEV_API_INTERNAL_HOST=http://api:3000 (Compose, not this file).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=env-utils.sh
source "$SCRIPT_DIR/env-utils.sh"
# shellcheck source=edge-origin.sh
source "$SCRIPT_DIR/edge-origin.sh"

SHARED_ENV_FILE="${SHARED_ENV_FILE:-$REPOSITORY_ROOT/.env.shared}"

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

stamp_file() {
  local env_file="$1"
  local origin="$2"
  local api_url="$3"
  local hostname="$4"
  local proto="$5"

  set_env_value "$env_file" EDGE_PUBLIC_URL "$origin"
  set_env_value "$env_file" HUB_PUBLIC_URL "$origin"
  set_env_value "$env_file" NEXT_PUBLIC_HOST "$origin"
  set_env_value "$env_file" NEXTAUTH_URL "$origin"
  set_env_value "$env_file" API_PUBLIC_URL "$api_url"
  set_env_value "$env_file" NEXT_PUBLIC_URANTIA_DEV_API_HOST "$api_url"
  set_env_value "$env_file" EDGE_HOSTNAME "$hostname"
  set_env_value "$env_file" EDGE_FORWARDED_PROTO "$proto"
  set_env_value "$env_file" CADDY_API_PATH "$(normalize_api_path "$(read_env_value "$SHARED_ENV_FILE" CADDY_API_PATH)")"
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

targets=("$SHARED_ENV_FILE")
for env_file in "$@"; do
  [[ -f "$env_file" ]] || continue
  targets+=("$env_file")
done

for env_file in "${targets[@]}"; do
  [[ -f "$env_file" ]] || continue
  stamp_file "$env_file" "$origin" "$api_url" "$hostname" "$proto"
done
