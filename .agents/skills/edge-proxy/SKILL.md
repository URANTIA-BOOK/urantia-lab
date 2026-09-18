---
name: edge-proxy
description: >-
  Use when changing urantia-lab's Caddy edge, EDGE_PUBLIC_URL, /dev-api, the
  Cloudflare localhost:8080 route, or stamp-edge-urls. Do not use for pipeline
  split/commit work or for adding a language tree.
---

# Lab edge proxy

One published origin. The hub already owns `/api` (NextAuth) and `/papers`, so
the papers API is mounted at `CADDY_API_PATH` (default `/dev-api`).

Follow the org `single-origin-edge` and `docker-local` skills. This file is
only the lab contract.

## Do this

1. `stack/edge` is the Caddy stack. `make up` includes `edge-up` last.
   Caddy joins `apps` only.
2. `make init` writes `.env.shared` once. The first TTY write sets
   `INIT_INTERVIEW=1` and asks for the published port (default `8080`), the
   papers API path (default `/dev-api`), and a hostname to expose. Later
   `make init` / `make up` keep the file (`existing_env_choice`). `make up`
   starts stacks; it does not run `make validate`. Choosers sourced by
   tests must not interview just because stdin is a TTY. `HTTP_PORT` /
   `CADDY_HTTP_PORT` / `CADDY_API_PATH` / `EDGE_PUBLIC_URL` overwrite.
   `make/stamp-edge-urls.sh` keeps a localhost origin on `CADDY_HTTP_PORT`
   and derives
   `EDGE_HOSTNAME`, `EDGE_FORWARDED_PROTO`, `HUB_PUBLIC_URL`,
   `NEXT_PUBLIC_HOST`, `NEXTAUTH_URL`, `API_PUBLIC_URL`, and
   `NEXT_PUBLIC_URANTIA_DEV_API_HOST`.
3. Hub SSR stays on `URANTIA_DEV_API_INTERNAL_HOST=http://api:3000`. Rebuild
   the hub image after a public-URL stamp; `NEXT_PUBLIC_*` bake in at
   `docker build`. Caddy host-matches `CADDY_HOST_MATCHERS` (unique
   hostname plus loopback). Do not list `EDGE_HOSTNAME` and `localhost`
   as separate literals — the default hostname is localhost and Caddy
   rejects a repeated host.
4. The Cloudflare published route is `http://localhost:8080`. Do not move
   Caddy off that host port without changing the tunnel.
5. `make verify` probes `127.0.0.1:$CADDY_HTTP_PORT` and the stamped public
   URLs. `make review` is still the human language gate.
6. Close the turn on `MODE=prod` (hub `yarn start`, API `bun run start`).
   `MODE=dev` is only for in-turn hot reload. See
   `.cursor/rules/staging-prod-mode.mdc`.
7. `./make/test-edge-urls.sh` and `./make/test-prod-mode.sh` run from
   `make validate`.
8. Do not claim `make up` from this checkout. Detach a worktree at
   `HEAD` (`git worktree add --detach` — the same branch cannot be
   checked out twice), `git submodule update --init --recursive`,
   then `make init PROJECT_NAME=<unique> HTTP_PORT=<free>
   CADDY_API_PATH=/v1` and `make up` with overwrite keys unset.
   Probe `/`, `$CADDY_API_PATH/health`, and `Host: evil.example`.
   Contract tests do not start Caddy.

## Not this

- Mounting the papers API at `/api` or `/papers`.
- Importing Wealth Hasura, Auth0, or Portainer.
- Claiming `make up` from the operator checkout or from leftover
  containers. Prove it on a detached worktree.
- Claiming languages verified from `make verify` alone.
- Editing `metadata.json` or treating the lab as the book text owner.
