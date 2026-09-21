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
# The environment boot (`uklok-agent boot`) injects the `aipal-agent_gh`
# SSH identity, which is a member with access to the private repo. This
# script fetches every submodule through that SSH identity: it applies an
# org-scoped https -> git@github.com rewrite for the fetch only. The
# override is longer than the managed host-level https rewrite, so
# longest-prefix matching wins, and nothing is written to the repository.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPOSITORY_ROOT"

git_override=()
origin_url="$(git config --get remote.origin.url || true)"
if [[ "$origin_url" =~ github\.com[:/]+([^/]+)/ ]]; then
  org="${BASH_REMATCH[1]}"

  # Prefer the SSH identity that boot injects. If the key file is not on
  # disk yet (for example during an environment build, before boot runs),
  # materialize it from the injected SSH_GITHUB secret. The key lives in
  # $HOME, never in the repository.
  gh_key="$HOME/.ssh/aipal-agent_gh"
  if [[ ! -f "$gh_key" && -n "${SSH_GITHUB:-}" ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    printf '%s\n' "$SSH_GITHUB" >"$gh_key"
    chmod 600 "$gh_key"
  fi

  if [[ -f "$gh_key" ]]; then
    export GIT_SSH_COMMAND="ssh -i $gh_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    git_override=(-c "url.git@github.com:${org}/.insteadOf=https://github.com/${org}/")
    echo "cloud-agent-install: fetching github.com/${org} submodules over the SSH identity"
  else
    echo "cloud-agent-install: no SSH identity for github.com; relying on ambient git credentials" >&2
  fi
else
  echo "cloud-agent-install: could not derive org from origin; relying on ambient git credentials" >&2
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
