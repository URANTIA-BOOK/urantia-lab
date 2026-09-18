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
# shellcheck source=edge-origin.sh
source "$SCRIPT_DIR/edge-origin.sh"

if [[ ! -f "$SHARED_ENV_EXAMPLE" ]]; then
  echo "missing $SHARED_ENV_EXAMPLE" >&2
  exit 1
fi

existed=false
[[ -f "$SHARED_ENV_FILE" ]] && existed=true
if [[ "$existed" != "true" ]]; then
  cp "$SHARED_ENV_EXAMPLE" "$SHARED_ENV_FILE"
  echo "created $SHARED_ENV_FILE"
  if [[ -t 0 ]]; then
    INIT_INTERVIEW=1
  fi
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

# Leftover sibling-layout keys must not remount UKLOK_ROOT trees.
unset_env_value "$SHARED_ENV_FILE" UKLOK_ROOT
set_env_value "$SHARED_ENV_FILE" PIPELINE_ROOT "$REPOSITORY_ROOT/pipeline"
set_env_value "$SHARED_ENV_FILE" API_ROOT "$REPOSITORY_ROOT/api"
set_env_value "$SHARED_ENV_FILE" HUB_ROOT "$REPOSITORY_ROOT/hub"
set_env_value "$SHARED_ENV_FILE" DATA_SOURCES_ROOT "$REPOSITORY_ROOT/data-sources"
set_env_value "$SHARED_ENV_FILE" BOOK_TREE "$REPOSITORY_ROOT/pipeline/source"

papers_url="postgres://$(read_env_value "$SHARED_ENV_FILE" POSTGRES_USER):$(read_env_value "$SHARED_ENV_FILE" POSTGRES_PASSWORD)@postgres:5432/$(read_env_value "$SHARED_ENV_FILE" POSTGRES_DB)"
hub_url="postgres://$(read_env_value "$SHARED_ENV_FILE" POSTGRES_USER):$(read_env_value "$SHARED_ENV_FILE" POSTGRES_PASSWORD)@postgres:5432/$(read_env_value "$SHARED_ENV_FILE" HUB_DB)"
redis_url="redis://:$(read_env_value "$SHARED_ENV_FILE" REDIS_PASSWORD)@redis:6379"

set_env_value "$SHARED_ENV_FILE" PAPERS_DATABASE_URL "$papers_url"
set_env_value "$SHARED_ENV_FILE" HUB_DATABASE_URL "$hub_url"
set_env_value "$SHARED_ENV_FILE" REDIS_URL "$redis_url"

host_port="$(read_env_value "$SHARED_ENV_FILE" POSTGRES_HOST_PORT)"
redis_port="$(read_env_value "$SHARED_ENV_FILE" REDIS_HOST_PORT)"
set_env_value "$SHARED_ENV_FILE" PAPERS_DATABASE_URL_HOST "postgres://$(read_env_value "$SHARED_ENV_FILE" POSTGRES_USER):$(read_env_value "$SHARED_ENV_FILE" POSTGRES_PASSWORD)@127.0.0.1:${host_port}/$(read_env_value "$SHARED_ENV_FILE" POSTGRES_DB)"
set_env_value "$SHARED_ENV_FILE" HUB_DATABASE_URL_HOST "postgres://$(read_env_value "$SHARED_ENV_FILE" POSTGRES_USER):$(read_env_value "$SHARED_ENV_FILE" POSTGRES_PASSWORD)@127.0.0.1:${host_port}/$(read_env_value "$SHARED_ENV_FILE" HUB_DB)"
set_env_value "$SHARED_ENV_FILE" REDIS_URL_HOST "redis://:$(read_env_value "$SHARED_ENV_FILE" REDIS_PASSWORD)@127.0.0.1:${redis_port}"

caddy_port="$(choose_caddy_http_port "$(read_env_value "$SHARED_ENV_FILE" CADDY_HTTP_PORT)" "$existed")"
if ! valid_http_port "$caddy_port"; then
  echo "Published port must be an integer 1-65535 (got '$caddy_port')." >&2
  exit 1
fi
set_env_value "$SHARED_ENV_FILE" CADDY_HTTP_PORT "$caddy_port"

api_path="$(choose_caddy_api_path "$(read_env_value "$SHARED_ENV_FILE" CADDY_API_PATH)" "$existed")"
set_env_value "$SHARED_ENV_FILE" CADDY_API_PATH "$api_path"

edge_url="$(choose_edge_public_url "$(read_env_value "$SHARED_ENV_FILE" EDGE_PUBLIC_URL)" "$existed" "$caddy_port")"
set_env_value "$SHARED_ENV_FILE" EDGE_PUBLIC_URL "$edge_url"

SHARED_ENV_FILE="$SHARED_ENV_FILE" "$SCRIPT_DIR/stamp-edge-urls.sh"

echo "Lab identity: COMPOSE_PROJECT_NAME=$name"
echo "Review URLs: hub $(read_env_value "$SHARED_ENV_FILE" HUB_PUBLIC_URL)  api $(read_env_value "$SHARED_ENV_FILE" API_PUBLIC_URL)"
