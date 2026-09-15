#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHARED_ENV_FILE="${SHARED_ENV_FILE:-$REPOSITORY_ROOT/.env.shared}"
# shellcheck source=env-utils.sh
source "$SCRIPT_DIR/env-utils.sh"

api="$(read_env_value "$SHARED_ENV_FILE" API_PUBLIC_URL)"
hub="$(read_env_value "$SHARED_ENV_FILE" HUB_PUBLIC_URL)"

fail() { echo "verify failed: $*" >&2; exit 1; }

curl -fsS "$api/health" >/dev/null || fail "API /health"
english="$(curl -fsS "$api/papers/1")"
echo "$english" | grep -q "Universal Father" || fail "English paper 1 title"
spanish="$(curl -fsS "$api/papers/1?lang=es")"
echo "$spanish" | grep -qi "Padre Universal" || fail "Spanish overlay on paper 1"
langs="$(curl -fsS "$api/languages")"
echo "$langs" | grep -q '"code":"es"' || fail "languages list"
curl -fsS -o /dev/null "$hub/" || fail "hub /"
curl -fsS -o /dev/null "$hub/papers/paper-1-the-universal-father" || fail "hub English paper 1"
curl -fsS -o /dev/null "$hub/papers/paper-1-the-universal-father?lang=es" || fail "hub Spanish paper 1"

echo "verify: API health, English paper 1, Spanish overlay, hub reader — ok"
