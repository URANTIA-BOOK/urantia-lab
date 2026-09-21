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
   `make/stamp-edge-urls.sh` keeps a bind-port origin (localhost, LAN IP,
   `*.local`) on `CADDY_HTTP_PORT` as `http` and derives those public keys
   onto `.env.shared` only. A public hostname stays `https` without that
   port. `0.0.0.0` is not an origin. A stack `.env`
   is stamped only for keys its `.env.example` already owns; leftover
   identity copies are stripped. Compose interpolates `CADDY_HTTP_PORT`
   from `--env-file .env.shared`. Do not pin that key on `COMPOSE :=`.
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
   `make dev-up` / `MODE=dev` is the overlay door (hot reload and
   diagnostic host ports from `.env.shared`). Flip back to `make up`
   before you finish. See `.cursor/rules/staging-prod-mode.mdc`.
   Network planes: `.agents/skills/stack-networks/SKILL.md`.
7. `./make/test-edge-urls.sh`, `./make/test-prod-mode.sh`, and
   `./make/test-dev-mode.sh` run from `make validate`.
8. Do not claim `make up` from this checkout. Detach a worktree at
   `HEAD` (`git worktree add --detach` — the same branch cannot be
   checked out twice), `git submodule update --init --recursive`,
   then `make init PROJECT_NAME=<unique> HTTP_PORT=<free>
   CADDY_API_PATH=/v1` and `make up` with overwrite keys unset.
   Probe `/`, `$CADDY_API_PATH/health`, and `Host: evil.example`.
   Then close the copy: `make destroy CONFIRM=true` and
   `git worktree remove`. A prove stack that stays up is leftover
   containers, volumes, networks, and `${PROJECT_NAME}-*:local`
   images. Contract tests do not start Caddy.

## Not this

- Joining postgres to `apps` so a diagnostic host port can bind.
- Joining hub to `backend` so Prisma or Redis TCP can reach the data plane.
- Leaving the papers adapter up after replacing postgres (stale TCP →
  `/health` 503 while Caddy still serves hub `/`).
- Mounting the papers API at `/api` or `/papers`.
- Importing Wealth Hasura, Auth0, or Portainer.
- Claiming `make up` from the operator checkout or from leftover
  containers. Prove it on a detached worktree, then destroy that
  copy. Do not leave a second Compose project running.
- Claiming languages verified from `make verify` alone.
- Editing `metadata.json` or treating the lab as the book text owner.
