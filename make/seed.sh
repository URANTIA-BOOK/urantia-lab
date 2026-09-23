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
  # exec inherits this script's stdin. A langs-status loop would lose every
  # row after the first overlay if compose read that stream.
  COMPOSE_PROJECT_NAME="$name" COMPOSE_IGNORE_ORPHANS=true \
    API_ROOT="$API_ROOT" PIPELINE_ROOT="$PIPELINE_ROOT" \
    docker compose --project-name "$name" \
      --project-directory "$REPOSITORY_ROOT/stack/api" \
      --env-file "$REPOSITORY_ROOT/stack/api/.env" \
      --env-file "$SHARED_ENV_FILE" \
      -f "$REPOSITORY_ROOT/stack/api/docker-compose.yml" \
      "$@" </dev/null
}

usage_seed_lang() {
  echo "Usage: make seed-lang L=es|fr|de" >&2
  echo "   or: make seed-lang KEY=cze [L=cs]" >&2
  echo "KEY is a pipeline/langs/registry.json key or repo (cze, spa_int, spanish_eur)." >&2
}

lookup_registry() {
  local key="$1"
  make -s --no-print-directory -C "$PIPELINE_ROOT" lang-lookup L="$key"
}

lookup_field() {
  local blob="$1" field="$2"
  printf '%s\n' "$blob" | awk -F= -v n="$field" '$1==n { print substr($0, length($1)+2); exit }'
}

overlay_lang() {
  local api_lang="${1:-}"
  local tree_name="$2"
  local tree="$PIPELINE_ROOT/langs/$tree_name"
  if [[ ! -f "$tree/metadata.json" ]]; then
    return 0
  fi
  if [[ -n "$api_lang" ]]; then
    echo "==> overlay $tree_name companions as lang=$api_lang"
    compose_api exec -T api bun run seed:tree -- \
      --tree="/book/langs/$tree_name" --lang="$api_lang"
    return
  fi
  echo "==> overlay $tree_name companions (lang from metadata)"
  compose_api exec -T api bun run seed:tree -- \
    --tree="/book/langs/$tree_name"
}

# langs-status columns: key, repo, parent, raw, built, br, tag.
# `built` is the edition the lab can load. Color codes are display only.
parse_langs_status() {
  sed $'s/\033\\[[0-9;]*m//g' | awk '
    $1 == "key" && $5 == "built" { next }
    NF < 5 { next }
    $5 != "yes" && $5 != "no" { next }
    { printf "%s\t%s\t%s\n", $1, $2, $5 }
  '
}

langs_status_rows() {
  make -s --no-print-directory -C "$PIPELINE_ROOT" langs-status | parse_langs_status
}

seed_built_editions() {
  local rows key repo built tree
  rows="$(langs_status_rows)"
  if [[ -z "$rows" ]]; then
    echo "langs-status reported no editions" >&2
    exit 1
  fi
  if ! printf '%s\n' "$rows" | awk -F '\t' '$2 == "source" && $3 == "yes" { found = 1 } END { exit !found }'; then
    echo "langs-status has no built English tree" >&2
    exit 1
  fi

  echo "==> langs-status"
  while IFS=$'\t' read -r key repo built; do
    [[ -z "${key:-}" ]] && continue
    if [[ "$built" != "yes" ]]; then
      echo "==> skip $key ($repo), not built"
    fi
  done <<< "$rows"

  echo "==> seed English tree"
  compose_api exec -T api bun run seed

  while IFS=$'\t' read -r key repo built; do
    [[ -z "${key:-}" ]] && continue
    [[ "$built" != "yes" || "$repo" == "source" ]] && continue
    tree="$PIPELINE_ROOT/langs/$repo/metadata.json"
    if [[ ! -f "$tree" ]]; then
      echo "langs-status marks $key built, but $tree is missing" >&2
      exit 1
    fi
    echo "==> seed $key ($repo)"
    overlay_lang "" "$repo"
  done <<< "$rows"
}

ensure_registry_tree() {
  local key="$1"
  local rel_tree="$2"
  local built="$3"
  local abs="$PIPELINE_ROOT/$rel_tree"
  if [[ "$built" == "yes" && -f "$abs/metadata.json" ]]; then
    echo "==> $key already processed ($rel_tree)"
    return 0
  fi
  echo "==> $key missing locally; make -C pipeline lang-run L=$key LOCAL=1"
  make -C "$PIPELINE_ROOT" lang-run L="$key" LOCAL=1
  if [[ ! -f "$abs/metadata.json" ]]; then
    echo "lang-run did not produce $abs/metadata.json" >&2
    exit 1
  fi
}

seed_registry_key() {
  local want="$1"
  local api_lang="${2:-}"
  local blob key repo tree built
  echo "==> registry lookup KEY=$want"
  blob="$(lookup_registry "$want")"
  printf '%s\n' "$blob"
  key="$(lookup_field "$blob" key)"
  repo="$(lookup_field "$blob" repo)"
  tree="$(lookup_field "$blob" tree)"
  built="$(lookup_field "$blob" built)"
  if [[ -z "$key" || -z "$repo" || -z "$tree" ]]; then
    echo "pipeline lang-lookup did not return key/repo/tree for $want" >&2
    exit 1
  fi
  ensure_registry_tree "$key" "$tree" "$built"
  echo "==> migrate papers database"
  compose_api exec -T api bun run db:migrate
  if [[ "$repo" == "source" ]]; then
    echo "==> seed English tree"
    compose_api exec -T api bun run seed
  else
    if [[ ! -f "$PIPELINE_ROOT/langs/$repo/metadata.json" ]]; then
      echo "No processed tree at $PIPELINE_ROOT/langs/$repo" >&2
      exit 1
    fi
    overlay_lang "$api_lang" "$repo"
  fi
  echo "Seed complete."
}

run_seed() {
  local ONLY_LANG="${L:-${1:-}}"
  local REGISTRY_KEY="${KEY:-}"

  if [[ -n "$REGISTRY_KEY" ]]; then
    seed_registry_key "$REGISTRY_KEY" "$ONLY_LANG"
    return 0
  fi

  echo "==> migrate papers database"
  compose_api exec -T api bun run db:migrate

  if [[ -n "$ONLY_LANG" ]]; then
    case "$ONLY_LANG" in
      es)
        overlay_lang es spanish
        overlay_lang es spanish_eur
        ;;
      fr) overlay_lang fr french ;;
      de) overlay_lang de german ;;
      *)
        usage_seed_lang
        return 2
        ;;
    esac
    echo "Seed complete."
    return 0
  fi

  seed_built_editions
  echo "Seed complete."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_seed "$@"
fi
