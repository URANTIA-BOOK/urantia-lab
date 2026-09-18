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
2. `make init` defaults `EDGE_PUBLIC_URL` to `http://localhost:8080`. On a TTY
   it asks for the published port (default `8080`), the papers API path
   (default `/dev-api`), and a hostname to expose. `HTTP_PORT` /
   `CADDY_HTTP_PORT` and `CADDY_API_PATH` are env overwrites.
   `make/stamp-edge-urls.sh` derives
   `EDGE_HOSTNAME`, `EDGE_FORWARDED_PROTO`, `HUB_PUBLIC_URL`,
   `NEXT_PUBLIC_HOST`, `NEXTAUTH_URL`, `API_PUBLIC_URL`, and
   `NEXT_PUBLIC_URANTIA_DEV_API_HOST`.
3. Hub SSR stays on `URANTIA_DEV_API_INTERNAL_HOST=http://api:3000`. Rebuild
   the hub image after a public-URL stamp; `NEXT_PUBLIC_*` bake in at
   `docker build`. Caddy host-matches `EDGE_HOSTNAME` plus loopback.
4. The Cloudflare published route is `http://localhost:8080`. Do not move
   Caddy off that host port without changing the tunnel.
5. `make verify` probes `127.0.0.1:$CADDY_HTTP_PORT` and the stamped public
   URLs. `make review` is still the human language gate.
6. Close the turn on `MODE=prod` (hub `yarn start`, API `bun run start`).
   `MODE=dev` is only for in-turn hot reload. See
   `.cursor/rules/staging-prod-mode.mdc`.
7. `./make/test-edge-urls.sh` and `./make/test-prod-mode.sh` run from
   `make validate`.

## Not this

- Mounting the papers API at `/api` or `/papers`.
- Importing Wealth Hasura, Auth0, or Portainer.
- Claiming languages verified from `make verify` alone.
- Editing `metadata.json` or treating the lab as the book text owner.
