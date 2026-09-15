#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHARED_ENV_FILE="${SHARED_ENV_FILE:-$REPOSITORY_ROOT/.env.shared}"
SHARED_ENV_EXAMPLE="${SHARED_ENV_EXAMPLE:-$REPOSITORY_ROOT/.env.shared.example}"
# shellcheck source=project-name.sh
source "$SCRIPT_DIR/project-name.sh"
# shellcheck source=env-utils.sh
source "$SCRIPT_DIR/env-utils.sh"

if [[ ! -f "$SHARED_ENV_EXAMPLE" ]]; then
  echo "missing $SHARED_ENV_EXAMPLE" >&2
  exit 1
fi

existed=false
[[ -f "$SHARED_ENV_FILE" ]] && existed=true
if [[ "$existed" != "true" ]]; then
  cp "$SHARED_ENV_EXAMPLE" "$SHARED_ENV_FILE"
  echo "created $SHARED_ENV_FILE"
fi

current="$(read_env_value "$SHARED_ENV_FILE" COMPOSE_PROJECT_NAME)"
name="$(choose_compose_project_name "$current" "$existed")"
if ! valid_compose_project_name "$name"; then
  echo "Invalid COMPOSE_PROJECT_NAME '$name'." >&2
  exit 1
fi
set_env_value "$SHARED_ENV_FILE" COMPOSE_PROJECT_NAME "$name"

ensure_secret "$SHARED_ENV_FILE" POSTGRES_PASSWORD
ensure_secret "$SHARED_ENV_FILE" REDIS_PASSWORD
ensure_secret "$SHARED_ENV_FILE" NEXTAUTH_SECRET

UKLOK_ROOT="$(cd "$REPOSITORY_ROOT/.." && pwd)"
set_env_value "$SHARED_ENV_FILE" UKLOK_ROOT "$UKLOK_ROOT"
set_env_value "$SHARED_ENV_FILE" PIPELINE_ROOT "$UKLOK_ROOT/URANTIA"
set_env_value "$SHARED_ENV_FILE" API_ROOT "$UKLOK_ROOT/urantia-dev-api"
set_env_value "$SHARED_ENV_FILE" HUB_ROOT "$UKLOK_ROOT/urantia-hub"
set_env_value "$SHARED_ENV_FILE" BOOK_TREE "$UKLOK_ROOT/URANTIA/source"

papers_url="postgres://$(read_env_value "$SHARED_ENV_FILE" POSTGRES_USER):$(read_env_value "$SHARED_ENV_FILE" POSTGRES_PASSWORD)@postgres:5432/$(read_env_value "$SHARED_ENV_FILE" POSTGRES_DB)"
hub_url="postgres://$(read_env_value "$SHARED_ENV_FILE" POSTGRES_USER):$(read_env_value "$SHARED_ENV_FILE" POSTGRES_PASSWORD)@postgres:5432/$(read_env_value "$SHARED_ENV_FILE" HUB_DB)"
redis_url="redis://:$(read_env_value "$SHARED_ENV_FILE" REDIS_PASSWORD)@redis:6379"

set_env_value "$SHARED_ENV_FILE" PAPERS_DATABASE_URL "$papers_url"
set_env_value "$SHARED_ENV_FILE" HUB_DATABASE_URL "$hub_url"
set_env_value "$SHARED_ENV_FILE" REDIS_URL "$redis_url"

host_port="$(read_env_value "$SHARED_ENV_FILE" POSTGRES_HOST_PORT)"
redis_port="$(read_env_value "$SHARED_ENV_FILE" REDIS_HOST_PORT)"
api_port="$(read_env_value "$SHARED_ENV_FILE" API_HOST_PORT)"
hub_port="$(read_env_value "$SHARED_ENV_FILE" HUB_HOST_PORT)"
set_env_value "$SHARED_ENV_FILE" PAPERS_DATABASE_URL_HOST "postgres://$(read_env_value "$SHARED_ENV_FILE" POSTGRES_USER):$(read_env_value "$SHARED_ENV_FILE" POSTGRES_PASSWORD)@127.0.0.1:${host_port}/$(read_env_value "$SHARED_ENV_FILE" POSTGRES_DB)"
set_env_value "$SHARED_ENV_FILE" HUB_DATABASE_URL_HOST "postgres://$(read_env_value "$SHARED_ENV_FILE" POSTGRES_USER):$(read_env_value "$SHARED_ENV_FILE" POSTGRES_PASSWORD)@127.0.0.1:${host_port}/$(read_env_value "$SHARED_ENV_FILE" HUB_DB)"
set_env_value "$SHARED_ENV_FILE" REDIS_URL_HOST "redis://:$(read_env_value "$SHARED_ENV_FILE" REDIS_PASSWORD)@127.0.0.1:${redis_port}"
set_env_value "$SHARED_ENV_FILE" API_PUBLIC_URL "http://127.0.0.1:${api_port}"
set_env_value "$SHARED_ENV_FILE" HUB_PUBLIC_URL "http://127.0.0.1:${hub_port}"
set_env_value "$SHARED_ENV_FILE" NEXT_PUBLIC_URANTIA_DEV_API_HOST "http://127.0.0.1:${api_port}"
set_env_value "$SHARED_ENV_FILE" NEXT_PUBLIC_HOST "http://127.0.0.1:${hub_port}"
set_env_value "$SHARED_ENV_FILE" NEXTAUTH_URL "http://127.0.0.1:${hub_port}"

if [[ -n "${HTTP_PORT:-}" ]]; then
  set_env_value "$SHARED_ENV_FILE" CADDY_HTTP_PORT "$HTTP_PORT"
elif [[ -z "$(read_env_value "$SHARED_ENV_FILE" CADDY_HTTP_PORT)" ]]; then
  set_env_value "$SHARED_ENV_FILE" CADDY_HTTP_PORT \
    "$(read_env_value "$SHARED_ENV_EXAMPLE" CADDY_HTTP_PORT)"
fi
if [[ -n "${CADDY_API_PATH:-}" ]]; then
  set_env_value "$SHARED_ENV_FILE" CADDY_API_PATH "$CADDY_API_PATH"
elif [[ -z "$(read_env_value "$SHARED_ENV_FILE" CADDY_API_PATH)" ]]; then
  set_env_value "$SHARED_ENV_FILE" CADDY_API_PATH \
    "$(read_env_value "$SHARED_ENV_EXAMPLE" CADDY_API_PATH)"
fi
if [[ -n "${EDGE_PUBLIC_URL:-}" ]]; then
  set_env_value "$SHARED_ENV_FILE" EDGE_PUBLIC_URL "${EDGE_PUBLIC_URL%/}"
elif [[ -z "$(read_env_value "$SHARED_ENV_FILE" EDGE_PUBLIC_URL)" ]]; then
  set_env_value "$SHARED_ENV_FILE" EDGE_PUBLIC_URL \
    "$(read_env_value "$SHARED_ENV_EXAMPLE" EDGE_PUBLIC_URL)"
fi

SHARED_ENV_FILE="$SHARED_ENV_FILE" "$SCRIPT_DIR/stamp-edge-urls.sh"

echo "Lab identity: COMPOSE_PROJECT_NAME=$name"
echo "Review URLs: hub $(read_env_value "$SHARED_ENV_FILE" HUB_PUBLIC_URL)  api $(read_env_value "$SHARED_ENV_FILE" API_PUBLIC_URL)"
