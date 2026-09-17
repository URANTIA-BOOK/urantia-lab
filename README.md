# Urantia lab

Local conductor for the reading platform. One copy of this repo is one Compose
project (default name `urantialab`). The lab default is `MODE=prod`: hub
`next start`, API `bun start`, and Caddy as the only published ingress, so
phone/Cloudflare traffic matches staging. `MODE=dev` adds hot reload and
diagnostic host ports.

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

`make init` defaults the published origin to `http://localhost:8080`. On a TTY
it asks for a hostname if you want to expose this copy. Hub/API/Next public
URLs and `EDGE_FORWARDED_PROTO` are derived from that origin plus
`CADDY_API_PATH` (default `/dev-api`). Caddy only serves `EDGE_HOSTNAME` and
loopback; any other Host gets 404.

```bash
make init                                          # localhost
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
| English tree (`pipeline/source`) | `make seed` | papers / paragraphs (upsert) |
| Spanish / French / German tree | `make seed-lang L=es` | `paragraph_translations` and titles |

Content comes from Postgres after seed. In `MODE=prod` the hub does not
watch code — recreate it after an app change (`make hub-up`). `MODE=dev`
(`yarn dev` / `bun --hot`) is only for an in-turn edit; flip back to
`make up` (prod) before you finish.

Pipeline markdown still needs `make lang-run` (or a split) before the tree JSON
companions exist. Editing a companion under `pipeline/langs/spanish` is enough for a
lab overlay refresh.

A second copy:

```bash
make init PROJECT_NAME=wt-review POSTGRES_HOST_PORT=5434 REDIS_HOST_PORT=6381 API_HOST_PORT=3010 HUB_HOST_PORT=3011 HTTP_PORT=8081
```

Stop or remove this copy:

```bash
make down                     # keeps volumes
make destroy CONFIRM=true     # containers, project volumes, and networks
```

`make help` lists the rest.
