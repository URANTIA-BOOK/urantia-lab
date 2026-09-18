#!/usr/bin/env bash
# destroy is scoped to one Compose project. A prove copy must be able
# to vanish without touching another copy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=project-name.sh
source "$SCRIPT_DIR/project-name.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

keep="labkeepcycle"
gone="labgonecycle"

cleanup() {
  docker rm -f "${gone}-dummy" "${keep}-dummy" >/dev/null 2>&1 || true
  docker volume rm "${gone}_data" "${keep}_data" >/dev/null 2>&1 || true
  docker network rm "${gone}-apps" "${keep}-apps" >/dev/null 2>&1 || true
  docker image rm "${gone}-api:local" "${gone}-hub:local" >/dev/null 2>&1 || true
  docker image rm "${keep}-api:local" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if CONFIRM= "$ROOT/make/destroy.sh" >/tmp/destroy-noconfirm.out 2>/tmp/destroy-noconfirm.err; then
  fail "destroy without CONFIRM=true must fail"
fi
grep -q 'CONFIRM=true' /tmp/destroy-noconfirm.err \
  || fail "destroy without confirm must print usage"

grep -q 'make destroy CONFIRM=true' "$ROOT/.agents/skills/edge-proxy/SKILL.md" \
  || fail "edge-proxy skill must close a prove copy with destroy"
grep -q 'make destroy' "$ROOT/AGENTS.md" \
  || fail "AGENTS.md must close a prove copy with destroy"

tmp="$(mktemp)"
printf 'COMPOSE_PROJECT_NAME=%s\n' "$gone" >"$tmp"

docker volume create --label "com.docker.compose.project=$gone" "${gone}_data" >/dev/null
docker volume create --label "com.docker.compose.project=$keep" "${keep}_data" >/dev/null
docker network create --label "com.docker.compose.project=$gone" "${gone}-apps" >/dev/null
docker network create --label "com.docker.compose.project=$keep" "${keep}-apps" >/dev/null
docker tag caddy:2 "${gone}-api:local"
docker tag caddy:2 "${gone}-hub:local"
docker tag caddy:2 "${keep}-api:local"

SHARED_ENV_FILE="$tmp" CONFIRM=true "$ROOT/make/destroy.sh"

docker volume inspect "${gone}_data" >/dev/null 2>&1 \
  && fail "destroy must remove the named project's volumes"
docker volume inspect "${keep}_data" >/dev/null 2>&1 \
  || fail "destroy must leave another project's volumes"
docker network inspect "${gone}-apps" >/dev/null 2>&1 \
  && fail "destroy must remove the named project's networks"
docker network inspect "${keep}-apps" >/dev/null 2>&1 \
  || fail "destroy must leave another project's networks"
docker image inspect "${gone}-api:local" >/dev/null 2>&1 \
  && fail "destroy must remove ${gone}-api:local"
docker image inspect "${gone}-hub:local" >/dev/null 2>&1 \
  && fail "destroy must remove ${gone}-hub:local"
docker image inspect "${keep}-api:local" >/dev/null 2>&1 \
  || fail "destroy must leave another project's :local images"
docker image inspect caddy:2 >/dev/null 2>&1 \
  || fail "destroy must leave shared base images"

rm -f "$tmp"
echo "destroy: CONFIRM guard, one project, project-local images"
