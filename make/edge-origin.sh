# Published origin: localhost by default. A public hostname is opt-in.
# Derived values are stamped by stamp-edge-urls.sh from EDGE_PUBLIC_URL
# + CADDY_API_PATH. Do not read the process HOSTNAME (that is the machine).

DEFAULT_EDGE_HOSTNAME="${DEFAULT_EDGE_HOSTNAME:-localhost}"
DEFAULT_CADDY_API_PATH="${DEFAULT_CADDY_API_PATH:-/dev-api}"

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
      printf '%s' "$suggested"
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
