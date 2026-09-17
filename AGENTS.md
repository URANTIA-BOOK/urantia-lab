# Urantia lab — agent notes

## Product limits

- This repo orchestrates local pairs. It does not become the API, the hub, or
  the pipeline.
- Apps live as git submodules in this checkout (`hub/`, `api/`, `pipeline/`,
  `data-sources/`), pinned to URANTIA-BOOK `main`. Nested pipeline language
  trees initialize recursively. Do not restore a UKLOK_ROOT sibling layout.
- Lab default is `MODE=prod` (`next start` / `bun start`, Caddy only).
  `MODE=dev` is hot-reload plus diagnostic ports. Close every turn on prod
  so the Cloudflare origin matches staging (`.cursor/rules/staging-prod-mode.mdc`).
  Do not import Wealth's Hasura, Auth0, or Portainer.
  The narrow exception is a Caddy path-prefix edge (`stack/edge`) so one
  Cloudflare published route (`localhost:8080`) can reach the hub and the API.
  Browser traffic uses `EDGE_PUBLIC_URL` (default `http://localhost:8080`).
  A TTY `make init` asks before a public hostname. Derived values:
  `EDGE_HOSTNAME`, `EDGE_FORWARDED_PROTO`, `HUB_PUBLIC_URL`, `API_PUBLIC_URL`,
  `NEXT_PUBLIC_*`, `NEXTAUTH_URL`. Hub SSR stays on
  `URANTIA_DEV_API_INTERNAL_HOST=http://api:3000`. The papers API is mounted at
  `CADDY_API_PATH` (default `/dev-api`) because the hub already owns `/api`.
  Caddy `:80` host-matches `EDGE_HOSTNAME` plus loopback.
  Prod compose builds `hub/Dockerfile` and `api/Dockerfile` and bind-mounts
  book trees only. Module onboarding is each repo's `.devcontainer`.
- Audio stays on the public CDN for this train.
- Official Foundation trees supersede AI translations. Overlay `spa/fre/ger`
  as API `es/fr/de`.

## Operating contract

- The root Makefile is the door: `init`, `validate`, `validate-dev`, `up`,
  `seed`, `seed-lang`, `verify`, `review`, `down`, `destroy`.
- End every turn with `make up` (prod) and `make verify`. Do not leave
  `yarn dev` or `bun --hot` serving the published origin.
- `COMPOSE_PROJECT_NAME` in `.env.shared` isolates containers, volumes, and
  the networks `<name>-apps` / `<name>-backend`. The default name is
  `urantialab` so this copy does not share a Compose project with other
  local `urantia-*` containers. `PROJECT_NAME` is the Make overwrite. Export
  `COMPOSE_IGNORE_ORPHANS=true`.
- Each directory under `stack/` owns its Compose and Makefile.
  `make/compose.mk` is shared Compose behavior only.
- Network membership is responsibility: postgres and redis stay on `backend`;
  api and hub join `apps` and `backend`; Caddy joins `apps` only. Browser
  traffic uses `NEXT_PUBLIC_URANTIA_DEV_API_HOST` on the published edge; hub
  SSR uses `URANTIA_DEV_API_INTERNAL_HOST=http://api:3000`.
- `make verify` is the machine probe. `make review` is the human language
  gate. Do not claim languages verified until the operator has read paper 1
  in English and `?lang=es`.
- Cloud Agent Compose bind mounts need `uklok-agent docker-local` (org
  skill `docker-local`) before `make up`. The hosted `tcp://127.0.0.1:2375`
  engine cannot see this checkout. Edge contract: `.agents/skills/edge-proxy/SKILL.md`.

## Validation

- Compose changes: `make validate`.
- Lifecycle changes: `make up`, `make seed`, `make verify`, then `make review`.
- Never version `.env`, `.env.shared`, or generated secrets.
