# Urantia lab — agent notes

## Product limits

- This repo orchestrates local pairs. It does not become the API, the hub, or
  the pipeline.
- Apps live as git submodules in this checkout (`hub/`, `api/`, `pipeline/`,
  `data-sources/`), pinned to URANTIA-BOOK `main`. Nested pipeline language
  trees initialize recursively. Do not restore a UKLOK_ROOT sibling layout.
- Lab default is `MODE=prod` (`next start` / `bun start`, Caddy only).
  `MODE=dev` is the overlay door (`make dev-up` / `make postgres-up MODE=dev`):
  hot-reload plus diagnostic host ports from `docker-compose.dev.yml`.
  Postgres and Redis stay on `backend` only (Wealth overlay adds `ports:`
  and attaches `dev`, not `apps`). Hub stays on `apps` only and talks to
  the API there. Every `docker-compose.dev.yml` declares `dev`
  (`${COMPOSE_PROJECT_NAME}-dev`) and attaches its service so host ports
  can bind.
  Dual membership is the adapter (API today; an HTTP Redis bridge if hub
  needs Redis). After replacing postgres, recreate the papers adapter
  (`make api-up`) so TCP clients reconnect. Close every turn on prod so
  the Cloudflare origin matches staging (`.cursor/rules/staging-prod-mode.mdc`).
  Network contract: `.agents/skills/stack-networks/SKILL.md`.
  Inner-join map (Wealth Dash→hub, Hasura→api, postgres/redis stay,
  redis-http not this train) lives in that skill.
  Do not import Wealth's Hasura, Auth0, or Portainer.
  The narrow exception is a Caddy path-prefix edge (`stack/edge`) so one
  Cloudflare published route (`localhost:8080`) can reach the hub and the API.
  `.env.shared` is the only identity file. `make/stamp-edge-urls.sh` writes a
  key only if that file already owns it (stack `.env.example` is the owner
  list) and strips leftover identity copies. Compose interpolates
  `CADDY_HTTP_PORT` and `POSTGRES_HOST_PORT` from `--env-file .env.shared`.
  Do not pin those keys on `COMPOSE :=` and do not copy them onto stack
  `.env` files. Browser traffic uses `EDGE_PUBLIC_URL` (default
  `http://localhost:8080`). The first TTY `make init` asks for the published
  port (default `8080`), the papers API path, and a hostname to expose.
  Later `make init` / `make up` keep `.env.shared`. Make-time `HTTP_PORT` /
  `CADDY_API_PATH` / `EDGE_PUBLIC_URL` overwrite a stored key. Derived
  values stay on `.env.shared`: `EDGE_HOSTNAME`, `EDGE_FORWARDED_PROTO`,
  `HUB_PUBLIC_URL`, `API_PUBLIC_URL`, `NEXT_PUBLIC_*`, `NEXTAUTH_URL`.
  Hub SSR stays on `URANTIA_DEV_API_INTERNAL_HOST=http://api:3000`. The
  papers API is mounted at `CADDY_API_PATH` (default `/dev-api`) because the
  hub already owns `/api`. Caddy `:80` host-matches `CADDY_HOST_MATCHERS`
  (unique `EDGE_HOSTNAME` plus loopback; localhost as the hostname must not
  repeat). Prod compose builds `hub/Dockerfile` and `api/Dockerfile` and
  bind-mounts book trees only. Module onboarding is each repo's
  `.devcontainer`.
- Audio stays on the public CDN for this train.
- Official Foundation trees supersede AI translations. Overlay `spa/fre/ger`
  as API `es/fr/de`.

## Operating contract

- The root Makefile is the door: `init` writes identity (interviews once),
  `validate` is compose config plus contract tests, `up` starts the stacks
  in prod, `dev-up` applies the development overlays. `up` does not run
  `validate`. `seed`, `seed-lang`, `verify`, `review`, `down`, `dev-down`,
  `destroy` stay lifecycle doors.
- End every turn with `make up` (prod) and `make verify`. Do not leave
  `yarn dev` or `bun --hot` serving the published origin.
- `COMPOSE_PROJECT_NAME` in `.env.shared` isolates containers, volumes, and
  the networks `<name>-apps` / `<name>-backend` (and `<name>-dev` on
  `MODE=dev`). The default name is `urantialab` so this copy does not share
  a Compose project with other local `urantia-*` containers. `PROJECT_NAME`
  is the Make overwrite. Export `COMPOSE_IGNORE_ORPHANS=true`.
- Each directory under `stack/` owns its Compose and Makefile.
  `make/compose.mk` is shared Compose behavior only.
- Network membership is responsibility. Postgres and Redis stay on
  `backend`. Hub and Caddy stay on `apps`. API joins both (papers
  adapter). Do not join a base service to `apps` to publish a diagnostic
  port; attach `dev` on the overlay. Do not join hub to `backend` to
  reach Postgres or Redis.
  Browser traffic uses `NEXT_PUBLIC_URANTIA_DEV_API_HOST` on the published
  edge; hub SSR uses `URANTIA_DEV_API_INTERNAL_HOST=http://api:3000`.
- `make verify` is the machine probe. `make review` is the human language
  gate. Do not claim languages verified until the operator has read paper 1
  in English and `?lang=es`.
- Cloud Agent Compose bind mounts need `uklok-agent docker-local` (org
  skill `docker-local`) before `make up`. The hosted `tcp://127.0.0.1:2375`
  engine cannot see this checkout. Edge contract: `.agents/skills/edge-proxy/SKILL.md`.

## Validation

- Compose changes: `make validate`.
- Lifecycle changes: `make up`, `make seed`, `make verify`, then `make review`.
  Do not claim `make up` from this checkout — detach a worktree at `HEAD`
  with an isolated `PROJECT_NAME` and `HTTP_PORT`, then `make destroy
  CONFIRM=true` and remove the worktree (see
  `.agents/skills/edge-proxy/SKILL.md`). A second copy that stays up
  is residual mess.
- Never version `.env`, `.env.shared`, or generated secrets.
