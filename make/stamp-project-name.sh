#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=project-name.sh
source "$SCRIPT_DIR/project-name.sh"
# shellcheck source=env-utils.sh
source "$SCRIPT_DIR/env-utils.sh"

PROJECT_NAME=
PROJECT_NAME_OVERRIDE=
name="$(resolve_compose_project_name)"
if ! valid_compose_project_name "$name"; then
  echo "Invalid COMPOSE_PROJECT_NAME '$name'." >&2
  exit 1
fi

for env_file in "$@"; do
  [[ -f "$env_file" ]] || continue
  set_env_value "$env_file" COMPOSE_PROJECT_NAME "$name"
done
