# Published origin: localhost by default. A public hostname is opt-in.
# First write interviews. Later make init / make up keep .env.shared
# (existing_env_choice). stamp-edge-urls.sh derives browser URLs from
# EDGE_PUBLIC_URL + CADDY_API_PATH and keeps a localhost origin on the
# bind port. Do not read the process HOSTNAME (that is the machine).
# shellcheck source=env-utils.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-utils.sh"

DEFAULT_EDGE_HOSTNAME="${DEFAULT_EDGE_HOSTNAME:-localhost}"
DEFAULT_CADDY_API_PATH="${DEFAULT_CADDY_API_PATH:-/dev-api}"
DEFAULT_CADDY_HTTP_PORT="${DEFAULT_CADDY_HTTP_PORT:-8080}"

normalize_api_path() {
  local path="$1"
  path="/${path#/}"
  path="${path%/}"
  [[ -n "$path" ]] || path="$DEFAULT_CADDY_API_PATH"
  printf '%s' "$path"
}

origin_hostname() {
  local origin="$1"
  origin="${origin#http://}"
  origin="${origin#https://}"
  origin="${origin%%/*}"
  origin="${origin%%:*}"
  printf '%s' "$origin"
}

origin_scheme() {
  local origin="$1"
  case "$origin" in
    https://*) printf 'https' ;;
    *) printf 'http' ;;
  esac
}

valid_http_port() {
  local port="$1"
  [[ "$port" =~ ^[1-9][0-9]{0,4}$ ]] || return 1
  ((port <= 65535))
}

choose_caddy_http_port() {
  local current="${1:-}"
  local existed="${2:-false}"
  local suggested="$DEFAULT_CADDY_HTTP_PORT"
  local chosen value

  if chosen="$(existing_env_choice "${HTTP_PORT:-${CADDY_HTTP_PORT:-}}" "$current" "$existed")"; then
    printf '%s' "$chosen"
    return
  fi

  if [[ -t 0 ]]; then
    read -r -p "Published port [${suggested}]: " value
    value="${value:-$suggested}"
    if ! valid_http_port "$value"; then
      echo "Published port must be an integer 1-65535 (got '$value')." >&2
      return 1
    fi
    printf '%s' "$value"
    return
  fi

  printf '%s' "$suggested"
}

derive_edge_public_url() {
  local host="$1"
  local port="$2"
  if [[ "$host" == "localhost" || "$host" == "127.0.0.1" ]]; then
    printf 'http://%s:%s' "$host" "$port"
    return
  fi
  printf 'https://%s' "$host"
}

choose_edge_public_url() {
  local current="${1:-}"
  local existed="${2:-false}"
  local port="${3:-8080}"
  local suggested="http://localhost:${port}"
  local chosen value prompt_host

  if [[ -n "${EDGE_PUBLIC_URL:-}" ]]; then
    printf '%s' "${EDGE_PUBLIC_URL%/}"
    return
  fi
  if [[ -n "${EDGE_HOSTNAME:-}" ]]; then
    derive_edge_public_url "$EDGE_HOSTNAME" "$port"
    return
  fi
  if chosen="$(existing_env_choice "" "$current" "$existed")"; then
    printf '%s' "${chosen%/}"
    return
  fi

  if [[ -t 0 ]]; then
    prompt_host="$(origin_hostname "$suggested")"
    [[ -n "$prompt_host" ]] || prompt_host="$DEFAULT_EDGE_HOSTNAME"
    echo "Published origin defaults to localhost. Enter a hostname to expose this copy." >&2
    read -r -p "Published hostname [${prompt_host}]: " value
    if [[ -z "$value" ]]; then
      derive_edge_public_url "$prompt_host" "$port"
      return
    fi
    if [[ "$value" =~ ^https?:// ]]; then
      printf '%s' "${value%/}"
      return
    fi
    derive_edge_public_url "$value" "$port"
    return
  fi

  printf '%s' "$suggested"
}

choose_caddy_api_path() {
  local current="${1:-}"
  local existed="${2:-false}"
  local suggested="$DEFAULT_CADDY_API_PATH"
  local chosen value

  if [[ -n "${CADDY_API_PATH:-}" ]]; then
    normalize_api_path "$CADDY_API_PATH"
    return
  fi
  if chosen="$(existing_env_choice "" "$current" "$existed")"; then
    normalize_api_path "$chosen"
    return
  fi

  if [[ -t 0 ]]; then
    read -r -p "Papers API path [${suggested}]: " value
    if [[ -z "$value" ]]; then
      printf '%s' "$suggested"
      return
    fi
    normalize_api_path "$value"
    return
  fi

  printf '%s' "$suggested"
}
