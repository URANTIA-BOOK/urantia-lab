# Urantia lab

Local conductor for the reading platform. One copy of this repo is one Compose
project (default name `urantialab`). The lab default is `MODE=prod`: hub
`next start`, API `bun start`, and Caddy as the only published ingress, so
phone/Cloudflare traffic matches staging. `make dev-up` (`MODE=dev`) adds
the `docker-compose.dev.yml` overlays: hot reload and diagnostic host ports
from `.env.shared`. `.env.shared` is the only identity file; stack `.env`
files keep only the keys their `.env.example` already owns.

Hub, API, pipeline, and data-sources live here as git submodules. The lab
does not become those apps — it starts their local pairs and runs the
verification door.

```bash
git clone --recurse-submodules git@github.com:URANTIA-BOOK/urantia-lab.git
cd urantia-lab
make init
make up
make seed
make verify
make review
```

A plain clone still works: `make init` runs `git submodule update --init --recursive`.

`make review` is the language gate. You confirm Spanish (and French/German)
paper 1 is Foundation prose, not the English fallback.

`make init` writes `.env.shared` once. The first TTY write asks for the host
port (default `8080`), the papers API path (default `/dev-api`), and a
hostname if you want to expose this copy. Later `make init` and `make up`
keep those values and restamp derived URLs onto `.env.shared` only.
`make up` starts the stacks; it does not run the contract tests
(`make validate` does). Change a stored key with a Make-time overwrite
(`HTTP_PORT`, `CADDY_API_PATH`, `EDGE_PUBLIC_URL`), not by answering
prompts again. Hub/API/Next public URLs and `EDGE_FORWARDED_PROTO` follow
that origin plus `CADDY_API_PATH`. Localhost, a LAN IP, and `*.local`
stay on `CADDY_HTTP_PORT` as `http`. A public hostname is `https` and
does not take the bind port (that bind is the tunnel target). `0.0.0.0`
is a listen address, not an origin. Compose interpolates `CADDY_HTTP_PORT` from `--env-file
.env.shared`. Caddy host-matches `CADDY_HOST_MATCHERS` (unique hostname
plus loopback). Any other Host gets 404.

```bash
make init                                          # localhost:8080
make init HTTP_PORT=9090
make init EDGE_PUBLIC_URL=https://urantia.uklok.cloud
make init CADDY_API_PATH=/dev-api HTTP_PORT=8080
```

Caddy listens on `CADDY_HTTP_PORT` (default `8080`). A Cloudflare tunnel whose
origin is `http://localhost:8080` can reach the hub (`/`) and the papers API
(`$CADDY_API_PATH`) once you stamp a public hostname. Hub SSR still calls
`http://api:3000` on the Compose network.

Hub and API run from their module Dockerfiles. Prod binds only book trees
(`pipeline/source`, `pipeline/langs`). Open `hub/.devcontainer` or
`api/.devcontainer` to onboard a module.

On a Cursor Cloud Agent, run `uklok-agent docker-local` (from environment
`start`, after `boot`) before `make up`. The hosted Docker engine cannot
bind-mount this checkout.

## Refresh book text without restarting the hub

The hub reads the API, not the pipeline files. Trees are bind-mounted into the
API container. After an edit, re-seed Postgres and refresh the browser.

| What you changed | Command | What updates |
| --- | --- | --- |
| Any built edition | `make seed` | English papers, then every overlay `langs-status` marks built |
| One short overlay | `make seed-lang L=es` | `es` (spanish + spanish_eur), `fr`, or `de` |
| One registry edition | `make seed-lang KEY=cze` | `lang-run LOCAL=1` if `langs/<repo>` is missing, then that overlay |

Content comes from Postgres after seed. In `MODE=prod` the hub does not
watch code — recreate it after an app change (`make hub-up`). `make
dev-up` (`yarn dev` / `bun --hot`, plus Postgres/Redis/API/hub host ports)
is only for an in-turn edit; flip back to `make up` (prod) before you
finish. `make postgres-up MODE=dev` is the same overlay door for one stack.
Postgres and Redis stay on `backend`. The overlay adds diagnostic
`ports:` and attaches `dev` (`${COMPOSE_PROJECT_NAME}-dev`) so Docker
can publish; it does not join `apps`. Hub stays on `apps` and reaches
papers through the API. Every `docker-compose.dev.yml` declares and
attaches that `dev` network.
After replacing postgres, recreate the papers adapter (`make api-up`)
so TCP clients reconnect. The map (Wealth Dash→hub, Hasura→api) is
`.agents/skills/stack-networks/SKILL.md`.

```bash
make validate-dev
make postgres-up MODE=dev
make dev-up
make verify
make dev-down
make up
```

`make seed` reads `make -C pipeline langs-status` and loads every edition
whose `built` column is `yes`. English is the base papers seed. Each other
built tree is an overlay; the API `?lang=` code comes from that tree's
metadata. A row that is not built is skipped. `make seed-lang KEY=cze`
still looks up `pipeline/langs/registry.json` and runs
`make -C pipeline lang-run L=cze LOCAL=1` when `langs/czech/metadata.json` is
missing. `L=es|fr|de` stays the short path for one overlay (`es` is spanish +
spanish_eur). Optional `L=` on a KEY run is the API `?lang=` override
(`make seed-lang L=cs KEY=cze`); omit it to take the code from metadata.

A second copy:

```bash
make init PROJECT_NAME=wt-review POSTGRES_HOST_PORT=5434 REDIS_HOST_PORT=6381 API_HOST_PORT=3010 HUB_HOST_PORT=3011 HTTP_PORT=8081
```

Stop or remove this copy:

```bash
make down                     # keeps volumes
make destroy CONFIRM=true     # containers, project volumes, networks, and this copy's :local images
```

`make help` lists the rest.
