---
name: stack-networks
description: >-
  Use when changing Compose networks, MODE=dev host ports, or which stack
  joins apps vs backend. Do not use for Caddy routes (edge-proxy) or for
  pipeline split/commit work.
---

# Lab network planes

Membership is responsibility. A service does not join a network to make a
host port bind, and a browser app does not join `backend` to reach
Postgres or Redis.

Follow Wealth's four connectivity limits (do not import Hasura, Auth0, or
Portainer). The adapter pattern is the inner-join: dual membership belongs
to the process that translates planes, never to the base service or the
proxy.

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
| Browser app on `apps` only | Dash (`API_URL` → Hasura on `apps`) | `hub` (`URANTIA_DEV_API_INTERNAL_HOST=http://api:3000`) |
| Papers / data adapter (`apps` + `backend`) | Hasura, Catalyst | `api` |
| Base data on `backend` only | PostgreSQL, KeyDB | `postgres`, `redis` |
| HTTP Redis from the apps plane | `redis-http` / `/upstash` (opt-in) | Not this train. Do not join hub or redis instead. |
| Published origin on `apps` | Caddy | Caddy |
| Management UI that needs both planes | pgAdmin, Redis Insight | Do not import |

`hub` joins `apps` only. `postgres` and `redis` join `backend` only.

## Who joins what

- `postgres` and `redis` join `backend` only. Consumers come to them.
  `MODE=dev` may add `ports:`. That does not move the service onto `apps`.
- `api` joins `apps` and `backend`. It is the papers adapter: hub and
  Caddy reach it on `apps`; it reaches Postgres on `backend`.
- `hub` joins `apps` only. SSR uses `URANTIA_DEV_API_INTERNAL_HOST=http://api:3000`.
  It does not take `DATABASE_URL` or `REDIS_URL` on the Compose service
  (Wealth Dash empties canonical names the container must not inherit).
  Lab overrides the image CMD to `yarn start` so `prisma migrate deploy`
  does not require a backend path. AUTH-on Prisma stays module debt.
- Redis from the apps plane, when needed, is an HTTP bridge that joins
  `apps` and `backend` (Wealth `redis-http` / `/upstash`). Do not join
  hub or redis to the other plane instead.
- Caddy joins `apps` only.

## Recreate the adapter

Replacing a backend container does not reconnect TCP clients already
running, and a new postgres volume is unmigrated. After
`make postgres-up`, run `make api-up` then `make seed`. Long-lived
Caddy stays on `apps` and resolves `api` by name; recreate Caddy only
when its healthcheck is stuck on a 502/503 from a dead adapter.

`/health` on the API is not "the container is up". It is "the adapter
can reach Postgres". A 200 health with `/languages` 500 means the
schema or overlays are missing — seed, do not join networks.

## Do this

1. Change membership on the service that owns the responsibility.
2. Keep diagnostic ports on the overlay of the service that already
   belongs on `backend` or `apps`. Do not join `apps` to publish a port.
3. Encode the membership in `make/test-prod-mode.sh` (prod planes).
4. After replacing postgres, recreate `api`, then `make seed`, then
   `make verify`.

## Not this

- Joining postgres or redis to `apps` so Docker binds a host port.
- Joining hub to `backend` so Prisma or Redis TCP works.
- Putting Caddy on `backend`.
- Importing Wealth Hasura, Auth0, or Portainer.
