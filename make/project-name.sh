#!/usr/bin/env bash
# Resolve the Compose project identity used to isolate containers, volumes, and networks.
# Precedence:
#   1. PROJECT_NAME (Make overwrite)
#   2. COMPOSE_PROJECT_NAME already in .env.shared
#   3. first-write interview / urantialab
# shellcheck source=env-utils.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-utils.sh"

DEFAULT_COMPOSE_PROJECT_NAME="${DEFAULT_COMPOSE_PROJECT_NAME:-urantialab}"

valid_compose_project_name() {
  local name="$1"
  [[ "$name" =~ ^[a-z0-9]([a-z0-9_-]*[a-z0-9])?$ ]]
}

read_compose_project_name_file() {
  local env_file="${SHARED_ENV_FILE:-}"
  [[ -n "$env_file" && -f "$env_file" ]] || return 0
  sed -n 's/^COMPOSE_PROJECT_NAME=//p' "$env_file" | tail -n 1
}

resolve_compose_project_name() {
  if [[ "${PROJECT_NAME_OVERRIDE:-}" == "1" && -n "${PROJECT_NAME:-}" ]]; then
    printf '%s' "$PROJECT_NAME"
    return
  fi
  local from_file
  from_file="$(read_compose_project_name_file)"
  if [[ -n "$from_file" ]]; then
    printf '%s' "$from_file"
    return
  fi
  printf '%s' "$DEFAULT_COMPOSE_PROJECT_NAME"
}

choose_compose_project_name() {
  local current="${1:-}"
  local existed="${2:-false}"
  local suggested="${current:-$DEFAULT_COMPOSE_PROJECT_NAME}"
  local value chosen

  [[ -n "$suggested" ]] || suggested="$DEFAULT_COMPOSE_PROJECT_NAME"

  if chosen="$(existing_env_choice "${PROJECT_NAME:-}" "$current" "$existed")"; then
    printf '%s' "$chosen"
    return
  fi
  if init_interviewing; then
    read -r -p "Compose project name [$suggested]: " value
    printf '%s' "${value:-$suggested}"
    return
  fi
  printf '%s' "$suggested"
}
