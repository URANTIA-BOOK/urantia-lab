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

apps="${name}-apps"
backend="${name}-backend"

docker network inspect "$apps" >/dev/null 2>&1 || docker network create "$apps" >/dev/null
docker network inspect "$backend" >/dev/null 2>&1 || docker network create --internal "$backend" >/dev/null
