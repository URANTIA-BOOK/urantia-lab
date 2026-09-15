# Urantia lab — agent notes

## Product limits

- This repo orchestrates local pairs. It does not become the API, the hub, or
  the pipeline.
- Apps are sibling checkouts under `UKLOK_ROOT` (`URANTIA`, `urantia-dev-api`,
  `urantia-hub`). Do not add them as submodules here.
- Lab default is `MODE=dev`. Do not import Wealth's Caddy, Hasura, or Auth0.
- Audio stays on the public CDN for this train.
- Official Foundation trees supersede AI translations. Overlay `spa/fre/ger`
  as API `es/fr/de`.

## Operating contract

- The root Makefile is the door: `init`, `validate`, `up`, `seed`,
  `seed-lang`, `verify`, `review`, `down`, `destroy`.
- `COMPOSE_PROJECT_NAME` in `.env.shared` isolates containers, volumes, and
  the networks `<name>-apps` / `<name>-backend`. The default name is
  `urantialab` so this copy does not share a Compose project with other
  local `urantia-*` containers. `PROJECT_NAME` is the Make overwrite. Export
  `COMPOSE_IGNORE_ORPHANS=true`.
- Each directory under `stack/` owns its Compose and Makefile.
  `make/compose.mk` is shared Compose behavior only.
- Network membership is responsibility: postgres and redis stay on `backend`;
  api and hub join `apps` and `backend`. Browser traffic uses
  `NEXT_PUBLIC_URANTIA_DEV_API_HOST` on the host; hub SSR uses
  `URANTIA_DEV_API_INTERNAL_HOST=http://api:3000`.
- `make verify` is the machine probe. `make review` is the human language
  gate. Do not claim languages verified until the operator has read paper 1
  in English and `?lang=es`.

## Validation

- Compose changes: `make validate`.
- Lifecycle changes: `make up`, `make seed`, `make verify`, then `make review`.
- Never version `.env`, `.env.shared`, or generated secrets.
