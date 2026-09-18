#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CADDY="$ROOT/stack/edge/Caddyfile"
COMPOSE="$ROOT/stack/edge/docker-compose.yml"
# shellcheck source=edge-origin.sh
source "$SCRIPT_DIR/edge-origin.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f "$CADDY" ]] || fail "missing $CADDY"

grep -q '{$CADDY_API_PATH}' "$CADDY" \
  || fail "Caddyfile must route the papers API from CADDY_API_PATH"
grep -q '@urantia host {$CADDY_HOST_MATCHERS}' "$CADDY" \
  || fail "Caddyfile must host-match the stamped unique list"
if grep -E 'host \{.*localhost' "$CADDY" | grep -q EDGE_HOSTNAME; then
  fail "Caddyfile must not hardcode localhost next to EDGE_HOSTNAME"
fi
local_hosts="$(caddy_host_matchers localhost 9080)"
[[ "$local_hosts" == "localhost 127.0.0.1 localhost:9080 127.0.0.1:9080" ]] \
  || fail "localhost matchers must be unique (got '$local_hosts')"
case " $local_hosts " in
  *" localhost localhost "*) fail "localhost must appear once" ;;
esac
grep -q 'unknown host' "$CADDY" \
  || fail "Caddyfile must 404 unknown hosts"
grep -q '{$EDGE_FORWARDED_PROTO}' "$CADDY" \
  || fail "Caddyfile must take forwarded proto from env"

if grep -q '^:80 {$' "$CADDY" && grep -A2 '^:80 {' "$CADDY" | grep -q 'import urantia_edge'; then
  fail "Caddy :80 must not import the app for every Host"
fi

grep -q './Caddyfile:/etc/caddy/Caddyfile' "$COMPOSE" \
  || fail "edge compose must bind-mount the Caddyfile (one source of truth)"
if grep -q 'configs:' "$COMPOSE"; then
  fail "edge compose must not embed a second Caddyfile"
fi

if [[ -f "$ROOT/.env.shared" ]] && command -v docker >/dev/null; then
  expected="$(sed -n 's/^CADDY_HTTP_PORT=//p' "$ROOT/.env.shared" | tail -n 1)"
  published="$(make -C "$ROOT/stack/edge" config \
    | awk '/published:/{gsub(/"/,""); print $2; exit}')" \
    || fail "edge compose config failed"
  [[ -n "$expected" && "$published" == "$expected" ]] \
    || fail "compose must publish shared CADDY_HTTP_PORT $expected (got '$published')"
fi

if command -v docker >/dev/null; then
  docker run --rm \
    -e CADDY_API_PATH=/v1 \
    -e CADDY_HOST_MATCHERS="$local_hosts" \
    -e EDGE_FORWARDED_PROTO=http \
    -v "$CADDY:/etc/caddy/Caddyfile:ro" \
    caddy:2 caddy validate --config /etc/caddy/Caddyfile >/dev/null \
    || fail "caddy validate must accept a localhost host list"
fi

echo "caddy-edge: host matcher and CADDY_API_PATH env are in the Caddyfile"
