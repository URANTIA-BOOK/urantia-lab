#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHARED_ENV_FILE="${SHARED_ENV_FILE:-$REPOSITORY_ROOT/.env.shared}"
# shellcheck source=env-utils.sh
source "$SCRIPT_DIR/env-utils.sh"

hub="$(read_env_value "$SHARED_ENV_FILE" HUB_PUBLIC_URL)"
api="$(read_env_value "$SHARED_ENV_FILE" API_PUBLIC_URL)"
edge="$(read_env_value "$SHARED_ENV_FILE" EDGE_PUBLIC_URL)"
edge="${edge%/}"

cat <<EOF
Human review — you are the gate.

Automated probes already passed if you ran make verify. Open these and confirm
the Spanish (and French/German if seeded) paper is the Foundation text, not
the English fallback.

  English paper 1
    $hub/papers/paper-1-the-universal-father

  Spanish paper 1 (lang=es, langs/spanish → UF-SPA-419-1993)
    $hub/papers/paper-1-the-universal-father?lang=es
    First paragraph should begin like: EL Padre Universal es el Dios de toda la creación

  French paper 1
    $hub/papers/paper-1-the-universal-father?lang=fr

  German paper 1
    $hub/papers/paper-1-the-universal-father?lang=de

  Languages endpoint
    $api/languages
EOF

if [[ -n "$edge" && "$edge" != "$hub" ]]; then
  cat <<EOF

  Same pair on the published edge ($edge)
    $edge/papers/paper-1-the-universal-father
    $edge/papers/paper-1-the-universal-father?lang=es
EOF
fi

cat <<EOF

Done when you can switch languages on the reader and the prose changes.
Audio still comes from the public CDN; that pair is opt-in later.
EOF

if command -v open >/dev/null 2>&1; then
  open "$hub/papers/paper-1-the-universal-father"
  open "$hub/papers/paper-1-the-universal-father?lang=es"
fi
