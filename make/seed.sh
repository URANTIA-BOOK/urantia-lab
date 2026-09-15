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
      -f "$REPOSITORY_ROOT/stack/api/docker-compose.dev.yml" \
      "$@"
}

echo "==> migrate papers database"
compose_api exec -T api bun run db:migrate

echo "==> seed English tree"
compose_api exec -T api bun run seed

spanish="$PIPELINE_ROOT/langs/spanish"
french="$PIPELINE_ROOT/langs/french"
german="$PIPELINE_ROOT/langs/german"

if [[ -f "$spanish/metadata.json" ]]; then
  echo "==> overlay Spanish companions as lang=es"
  compose_api exec -T api bun run seed:tree -- --tree=/book/langs/spanish --lang=es
fi
if [[ -f "$french/metadata.json" ]]; then
  echo "==> overlay French companions as lang=fr"
  compose_api exec -T api bun run seed:tree -- --tree=/book/langs/french --lang=fr
fi
if [[ -f "$german/metadata.json" ]]; then
  echo "==> overlay German companions as lang=de"
  compose_api exec -T api bun run seed:tree -- --tree=/book/langs/german --lang=de
fi

echo "Seed complete."
