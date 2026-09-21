#!/usr/bin/env bash
set -euo pipefail

# Cloud Agent bootstrap for the Urantia lab.
#
# A fresh Cursor Cloud Agent checks out this superproject but not its
# submodules. `hub`, `api`, and `data-sources` are public, but `pipeline`
# (and therefore its nested language trees) is private. Cursor's managed
# git config rewrites every https://github.com/ URL to embed its GitHub App
# token, which cannot read the private repo, so a plain
# `git submodule update --init --recursive` 404s on `pipeline`.
#
# This script re-initializes every submodule non-interactively. When a
# GH_TOKEN with private access is present it applies an org-scoped
# url.insteadOf override for the fetch only. The override is longer than
# the managed host-level rewrite, so longest-prefix matching wins, and the
# token is passed via `git -c` at runtime — never written to disk or the
# repository.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPOSITORY_ROOT"

git_override=()
origin_url="$(git config --get remote.origin.url || true)"
if [[ -n "${GH_TOKEN:-}" && "$origin_url" =~ github\.com[:/]+([^/]+)/ ]]; then
  org="${BASH_REMATCH[1]}"
  org_base="https://github.com/${org}/"
  git_override=(-c "url.https://x-access-token:${GH_TOKEN}@github.com/${org}/.insteadOf=${org_base}")
  echo "cloud-agent-install: using GH_TOKEN for github.com/${org} submodule fetch"
else
  echo "cloud-agent-install: GH_TOKEN not set; relying on ambient git credentials"
fi

# --force recovers a submodule left half-checked-out by an earlier aborted init.
git "${git_override[@]}" submodule sync --recursive
git "${git_override[@]}" submodule update --init --recursive --force

missing=0
for path in api/package.json hub/package.json \
  pipeline/source/metadata.json pipeline/langs/spanish/metadata.json; do
  if [[ ! -f "$path" ]]; then
    echo "cloud-agent-install: expected checkout missing: $path" >&2
    missing=1
  fi
done
[[ "$missing" -eq 0 ]] || exit 1

echo "cloud-agent-install: submodules ready (hub, api, data-sources, pipeline + language trees)"
