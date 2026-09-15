# Urantia lab

Local conductor for the reading platform. One copy of this repo is one Compose
project (default name `urantialab`). The lab default is `MODE=dev`: diagnostic
ports and sibling checkouts, not a production replica.

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

A second copy:

```bash
make init PROJECT_NAME=wt-review POSTGRES_HOST_PORT=5434 REDIS_HOST_PORT=6381 API_HOST_PORT=3010 HUB_HOST_PORT=3011
```

Stop or remove this copy:

```bash
make down                     # keeps volumes
make destroy CONFIRM=true     # containers, project volumes, and networks
```

`make help` lists the rest.
