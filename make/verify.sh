#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHARED_ENV_FILE="${SHARED_ENV_FILE:-$REPOSITORY_ROOT/.env.shared}"
# shellcheck source=env-utils.sh
source "$SCRIPT_DIR/env-utils.sh"

api="$(read_env_value "$SHARED_ENV_FILE" API_PUBLIC_URL)"
hub="$(read_env_value "$SHARED_ENV_FILE" HUB_PUBLIC_URL)"
edge_port="$(read_env_value "$SHARED_ENV_FILE" CADDY_HTTP_PORT)"
api_path="$(read_env_value "$SHARED_ENV_FILE" CADDY_API_PATH)"
api_path="${api_path:-/dev-api}"
api_path="/${api_path#/}"
api_path="${api_path%/}"

fail() { echo "verify failed: $*" >&2; exit 1; }

probe_api() {
  local origin="$1"
  local label="$2"
  curl -fsS --connect-timeout 10 --max-time 30 "$origin/health" >/dev/null \
    || fail "$label /health"
  local english spanish toc langs
  english="$(curl -fsS --connect-timeout 10 --max-time 30 "$origin/papers/1")"
  echo "$english" | grep -q "Universal Father" || fail "$label English paper 1 title"
  spanish="$(curl -fsS --connect-timeout 10 --max-time 30 "$origin/papers/1?lang=es")"
  echo "$spanish" | grep -qi "Padre Universal" || fail "$label Spanish overlay on paper 1"
  toc="$(curl -fsS --connect-timeout 10 --max-time 30 "$origin/toc?lang=es")"
  echo "$toc" | grep -qi "Padre Universal" || fail "$label Spanish TOC paper title"
  langs="$(curl -fsS --connect-timeout 10 --max-time 30 "$origin/languages")"
  echo "$langs" | grep -q '"code":"es"' || fail "$label languages list"
}

probe_hub() {
  local origin="$1"
  local label="$2"
  curl -fsS --connect-timeout 10 --max-time 30 -o /dev/null "$origin/" \
    || fail "$label /"
  curl -fsS --connect-timeout 10 --max-time 30 -o /dev/null \
    "$origin/papers/paper-1-the-universal-father" \
    || fail "$label English paper 1"
  curl -fsS --connect-timeout 10 --max-time 30 -o /dev/null \
    "$origin/papers/paper-1-the-universal-father?lang=es" \
    || fail "$label Spanish paper 1"
}

if [[ -n "$edge_port" ]]; then
  edge_local="http://127.0.0.1:${edge_port}"
  probe_api "${edge_local}${api_path}" "edge ${edge_local}${api_path}"
  probe_hub "$edge_local" "edge ${edge_local}"
fi

probe_api "$api" "API $api"
probe_hub "$hub" "hub $hub"

echo "verify: edge, API health, English paper 1, Spanish overlay, hub reader — ok"
