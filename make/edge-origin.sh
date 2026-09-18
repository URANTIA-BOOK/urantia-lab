# Published origin: localhost by default. A public hostname is opt-in.
# Derived values are stamped by stamp-edge-urls.sh from EDGE_PUBLIC_URL
# + CADDY_API_PATH. Do not read the process HOSTNAME (that is the machine).

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

  if [[ -n "${HTTP_PORT:-}" ]]; then
    printf '%s' "$HTTP_PORT"
    return
  fi
  if [[ -n "${CADDY_HTTP_PORT:-}" ]]; then
    printf '%s' "$CADDY_HTTP_PORT"
    return
  fi

  if [[ "$existed" == "true" && -n "$current" ]]; then
    suggested="$current"
  fi

  if [[ -t 0 ]]; then
    local value
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

  if [[ -n "${EDGE_PUBLIC_URL:-}" ]]; then
    printf '%s' "${EDGE_PUBLIC_URL%/}"
    return
  fi

  if [[ -n "${EDGE_HOSTNAME:-}" ]]; then
    derive_edge_public_url "$EDGE_HOSTNAME" "$port"
    return
  fi

  if [[ "$existed" == "true" && -n "$current" ]]; then
    suggested="${current%/}"
  fi

  if [[ -t 0 ]]; then
    local prompt_host
    prompt_host="$(origin_hostname "$suggested")"
    [[ -n "$prompt_host" ]] || prompt_host="$DEFAULT_EDGE_HOSTNAME"
    echo "Published origin defaults to localhost. Enter a hostname to expose this copy." >&2
    local value
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

  if [[ -n "${CADDY_API_PATH:-}" ]]; then
    normalize_api_path "$CADDY_API_PATH"
    return
  fi

  if [[ "$existed" == "true" && -n "$current" ]]; then
    suggested="$(normalize_api_path "$current")"
  fi

  if [[ -t 0 ]]; then
    local value
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
