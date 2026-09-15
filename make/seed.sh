#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHARED_ENV_FILE="${SHARED_ENV_FILE:-$REPOSITORY_ROOT/.env.shared}"
# shellcheck source=project-name.sh
source "$SCRIPT_DIR/project-name.sh"
# shellcheck source=env-utils.sh
source "$SCRIPT_DIR/env-utils.sh"

name="$(resolve_compose_project_name)"
API_ROOT="$(read_env_value "$SHARED_ENV_FILE" API_ROOT)"
PIPELINE_ROOT="$(read_env_value "$SHARED_ENV_FILE" PIPELINE_ROOT)"

compose_api() {
  COMPOSE_PROJECT_NAME="$name" COMPOSE_IGNORE_ORPHANS=true \
    API_ROOT="$API_ROOT" PIPELINE_ROOT="$PIPELINE_ROOT" \
    docker compose --project-name "$name" \
      --project-directory "$REPOSITORY_ROOT/stack/api" \
      --env-file "$REPOSITORY_ROOT/stack/api/.env" \
      --env-file "$SHARED_ENV_FILE" \
      -f "$REPOSITORY_ROOT/stack/api/docker-compose.yml" \
      "$@"
}

echo "==> migrate papers database"
compose_api exec -T api bun run db:migrate

overlay_lang() {
  local api_lang="$1"
  local tree_name="$2"
  local tree="$PIPELINE_ROOT/langs/$tree_name"
  if [[ -f "$tree/metadata.json" ]]; then
    echo "==> overlay $tree_name companions as lang=$api_lang"
    compose_api exec -T api bun run seed:tree -- --tree="/book/langs/$tree_name" --lang="$api_lang"
  fi
}

ONLY_LANG="${1:-}"
if [[ -n "$ONLY_LANG" ]]; then
  case "$ONLY_LANG" in
    es) overlay_lang es spanish ;;
    fr) overlay_lang fr french ;;
    de) overlay_lang de german ;;
    *)
      echo "Usage: make seed-lang L=es|fr|de" >&2
      exit 2
      ;;
  esac
  echo "Seed complete."
  exit 0
fi

echo "==> seed English tree"
compose_api exec -T api bun run seed

overlay_lang es spanish
overlay_lang fr french
overlay_lang de german

echo "Seed complete."
