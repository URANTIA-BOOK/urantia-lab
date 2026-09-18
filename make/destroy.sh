#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHARED_ENV_FILE="${SHARED_ENV_FILE:-$REPOSITORY_ROOT/.env.shared}"
# shellcheck source=project-name.sh
source "$SCRIPT_DIR/project-name.sh"

name="$(resolve_compose_project_name)"
if ! valid_compose_project_name "$name"; then
  echo "Invalid COMPOSE_PROJECT_NAME '$name'." >&2
  exit 1
fi

if [[ "${CONFIRM:-}" != "true" ]]; then
  echo "Destroying Compose project '$name' removes containers, project volumes, networks, and ${name}-*:local images." >&2
  echo "Usage: make destroy CONFIRM=true" >&2
  exit 1
fi

echo "Destroying Compose project '$name'"

container_ids="$(docker ps -aq --filter "label=com.docker.compose.project=$name" 2>/dev/null || true)"
[[ -n "$container_ids" ]] && docker rm -f $container_ids >/dev/null

volume_ids="$(docker volume ls -q --filter "label=com.docker.compose.project=$name" 2>/dev/null || true)"
[[ -n "$volume_ids" ]] && docker volume rm $volume_ids >/dev/null

network_ids="$(docker network ls -q --filter "label=com.docker.compose.project=$name" 2>/dev/null || true)"
[[ -n "$network_ids" ]] && docker network rm $network_ids >/dev/null || true

for network in "${name}-apps" "${name}-backend"; do
  docker network inspect "$network" >/dev/null 2>&1 || continue
  docker network rm "$network" >/dev/null || true
done

# One copy owns ${name}-api:local and ${name}-hub:local. Leave shared
# bases (caddy, postgres, redis) and every other project's tags.
for image in "${name}-api:local" "${name}-hub:local"; do
  docker image inspect "$image" >/dev/null 2>&1 || continue
  docker image rm "$image" >/dev/null || true
done

echo "Compose project '$name' destroyed."
