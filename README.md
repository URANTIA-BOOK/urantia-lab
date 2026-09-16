# Urantia lab

Local conductor for the reading platform. One copy of this repo is one Compose
project (default name `urantialab`). The lab default is `MODE=prod`: hub
`next start`, API `bun start`, and Caddy as the only published ingress, so
phone/Cloudflare traffic matches staging. `MODE=dev` adds hot reload and
diagnostic host ports.

It does not own book text, the API, or the hub. It starts their local pairs
and runs the verification door.

```bash
make init
make up
make seed
make verify
make review
```

`make review` is the language gate. You confirm Spanish (and French/German)
paper 1 is Foundation prose, not the English fallback.

Phone / Cloudflare review uses the published edge:

```text
https://urantia.uklok.cloud
https://urantia.uklok.cloud/dev-api/health
```

Caddy listens on `CADDY_HTTP_PORT` (default `8080`) so a dashboard tunnel whose
origin is `http://localhost:8080` can reach both the hub (`/`) and the papers
API (`/dev-api`). That prefix avoids the hub's NextAuth `/api` routes. `make
init` stamps `NEXT_PUBLIC_*` and `NEXTAUTH_URL` from `EDGE_PUBLIC_URL`. Hub SSR
still calls `http://api:3000` on the Compose network.

Overwrite doors: `make init EDGE_PUBLIC_URL=https://urantia.uklok.cloud HTTP_PORT=8080`.

On a Cursor Cloud Agent, run `uklok-agent docker-local` (from environment
`start`, after `boot`) before `make up`. The hosted Docker engine cannot
bind-mount this checkout.

## Refresh book text without restarting the hub

The hub reads the API, not the pipeline files. Trees are bind-mounted into the
API container. After an edit, re-seed Postgres and refresh the browser.

| What you changed | Command | What updates |
| --- | --- | --- |
| English tree (`URANTIA/source`) | `make seed` | papers / paragraphs (upsert) |
| Spanish / French / German tree | `make seed-lang L=es` | `paragraph_translations` and titles |

Content comes from Postgres after seed. In `MODE=prod` the hub does not
watch code — recreate it after an app change (`make hub-up`). `MODE=dev`
(`yarn dev` / `bun --hot`) is only for an in-turn edit; flip back to
`make up` (prod) before you finish.

Pipeline markdown still needs `make lang-run` (or a split) before the tree JSON
companions exist. Editing a companion under `langs/spanish` is enough for a
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
