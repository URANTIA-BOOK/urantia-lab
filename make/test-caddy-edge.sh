#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CADDY="$ROOT/stack/edge/Caddyfile"
COMPOSE="$ROOT/stack/edge/docker-compose.yml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f "$CADDY" ]] || fail "missing $CADDY"

grep -q '{$CADDY_API_PATH}' "$CADDY" \
  || fail "Caddyfile must route the papers API from CADDY_API_PATH"
grep -q '@urantia host' "$CADDY" \
  || fail "Caddyfile must host-match EDGE_HOSTNAME"
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

echo "caddy-edge: host matcher and CADDY_API_PATH env are in the Caddyfile"
