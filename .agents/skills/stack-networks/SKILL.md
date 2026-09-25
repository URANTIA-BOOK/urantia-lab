---
name: stack-networks
description: >-
  Use when changing Compose networks, MODE=dev host ports, or which stack
  joins apps vs backend. Do not use for Caddy routes (edge-proxy) or for
  pipeline split/commit work.
---

# Lab network planes

Membership is responsibility. A service does not join a network merely to
make a host port bind. Hub is a browser-facing app and a server-side owner of
Prisma user data and Redis-backed features, so it legitimately joins both
planes.

Follow Wealth's four connectivity limits (do not import Hasura, Auth0, or
Portainer). Dual membership belongs to a process that has responsibilities on
both planes, never to a base data service or the proxy.

Wealth is the infrastructure guide. Lab keeps only the inner-join.

## Limits

| Limit | Who | Host ports | Internet |
| --- | --- | --- | --- |
| Proxy | Caddy | Yes (the published origin) | Yes |
| Apps | hub, Caddy, API (front) | No in prod | Yes |
| Backend | postgres, redis | No in prod | No (`--internal`) |
| Development | `docker-compose.dev.yml` overlays | Diagnostic publishes only | Yes |

## Inner-join (Wealth → lab)

| Responsibility | Wealth | Lab |
| --- | --- | --- |
| Browser-facing app on `apps` | Dash (`API_URL` → Hasura on `apps`) | `hub` (`URANTIA_DEV_API_INTERNAL_HOST=http://api:3000`) |
| Papers / data adapter (`apps` + `backend`) | Hasura, Catalyst | `api` |
| Base data on `backend` only | PostgreSQL, KeyDB | `postgres`, `redis` |
| Server-side user data and cache | Catalyst / app backend | Hub Prisma + Redis clients on `backend` |
| Published origin on `apps` | Caddy | Caddy |
| Management UI that needs both planes | pgAdmin, Redis Insight | Do not import |

`hub` joins both `apps` and `backend`. `postgres` and `redis` join `backend` only.

## Who joins what

- `postgres` and `redis` join `backend` only. Consumers come to them.
  `MODE=dev` adds `ports:` and attaches the overlay network `dev`
  (`${COMPOSE_PROJECT_NAME}-dev`, not `--internal`) so Docker can
  publish. Overlay `networks:` replaces the base list: re-list the
  existing planes plus `dev`. That does not move the service onto
  `apps`. An `--internal` network may leave `NetworkSettings.Ports`
  null; that is not a reason to join `apps`.
- `api` joins `apps` and `backend`. It is the papers adapter: hub and
  Caddy reach it on `apps`; it reaches Postgres on `backend`.
- `hub` joins `apps` and `backend`. SSR uses
  `URANTIA_DEV_API_INTERNAL_HOST=http://api:3000` on `apps`; Prisma uses the
  Hub database and Redis-backed features use `REDIS_URL` on `backend`. The
  image runs `prisma migrate deploy` before Next.js and fails closed when the
  database is unavailable. Do not pass the papers database credential to Hub.
- Caddy joins `apps` only.

## Recreate the adapter

Replacing a backend container does not reconnect TCP clients already
running, and a new postgres volume is unmigrated. After
`make postgres-up`, run `make api-up`, `make hub-up`, then `make seed`. Long-lived
Caddy stays on `apps` and resolves `api` by name; recreate Caddy only
when its healthcheck is stuck on a 502/503 from a dead adapter.

`/health` on the API is not "the container is up". It is "the adapter
can reach Postgres". A 200 health with `/languages` 500 means the
schema or overlays are missing — seed, do not join networks.

## Do this

1. Change membership on the service that owns the responsibility. Hub owns
   its Prisma and Redis connections, so both belong on its Compose service.
2. Keep diagnostic ports on the overlay of the service that already
   belongs on `backend` or `apps`. Attach that overlay to `dev` so
   the host port can bind. Do not join `apps` to publish a port.
3. Encode the membership in `make/test-prod-mode.sh` (prod planes) and
   `make/test-dev-mode.sh` (every overlay declares `dev`; postgres/redis
   still do not join `apps`).
4. After replacing postgres, recreate `api` and `hub`, then `make seed`, then
   `make verify`.

## Not this

- Joining postgres or redis to `apps` so Docker binds a host port.
- Passing `PAPERS_DATABASE_URL` to Hub; its database is `HUB_DATABASE_URL`.
- Putting Caddy on `backend`.
- Importing Wealth Hasura, Auth0, or Portainer.
- Treating a null `NetworkSettings.Ports` on `--internal` as a reason
  to join `apps`. Attach `dev` instead.
