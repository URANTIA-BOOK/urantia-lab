include make/project.mk

DOCKER_COMPOSE ?= docker compose
MODE ?= prod

POSTGRES_DIR := stack/db/postgres
REDIS_DIR := stack/redis
API_DIR := stack/api
HUB_DIR := stack/hub
EDGE_DIR := stack/edge

ifeq ($(PROJECT_NAME_OVERRIDE),1)
STACK_MAKE := $(MAKE) PROJECT_NAME=$(PROJECT_NAME) MODE=$(MODE)
else
STACK_MAKE := $(MAKE) MODE=$(MODE)
endif

PROJECT_NAME_ENV := PROJECT_NAME_OVERRIDE=$(PROJECT_NAME_OVERRIDE) \
	PROJECT_NAME=$(if $(PROJECT_NAME_OVERRIDE),$(PROJECT_NAME),) \
	SHARED_ENV_FILE=$(SHARED_ENV_FILE)

DEFAULT_UP_TARGETS := postgres-up redis-up api-up hub-up edge-up
DEFAULT_DOWN_TARGETS := edge-down hub-down api-down redis-down postgres-down

.PHONY: help check-docker submodules check-siblings init env-check network validate \
	validate-dev \
	up down restart destroy ps logs verify seed seed-lang review \
	postgres-up postgres-down redis-up redis-down api-up api-down hub-up hub-down \
	edge-up edge-down

help:
	@echo "Urantia lab — local conductor for the reading platform"
	@echo ""
	@echo "git clone --recurse-submodules <this-repo>"
	@echo "make init && make up"
	@echo ""
	@echo "One copy of this repo is one Compose project (default name urantialab)."
	@echo "This lab's default is MODE=prod: next start / bun start, Caddy only."
	@echo "Phone/Cloudflare usage is staging. MODE=dev is hot-reload only."
	@echo ""
	@echo "  make init               Submodules + name this copy + local secrets"
	@echo "  make submodules         git submodule update --init --recursive"
	@echo "  make validate           Validate the selected Compose model"
	@echo "  make validate-dev       Validate MODE=dev overlays"
	@echo "  make up                 Postgres + Redis + API + hub + edge (prod)"
	@echo "  make seed               English tree + official translation overlays"
	@echo "  make seed-lang L=es     Re-upsert one overlay from its language tree"
	@echo "  make verify             Probe edge, API health, languages, and hub"
	@echo "  make review             Print the human language-review URLs"
	@echo "  make down               Stop this copy (keeps volumes)"
	@echo "  make destroy CONFIRM=true  Remove containers, volumes, and networks"
	@echo ""
	@echo "A second copy: make init PROJECT_NAME=wt-review POSTGRES_HOST_PORT=5434"

check-docker:
	@$(DOCKER_COMPOSE) version >/dev/null

submodules:
	@git -C "$(REPOSITORY_ROOT)" submodule update --init --recursive

check-siblings: submodules
	@test -f "$(API_ROOT)/package.json" || { echo "Missing API checkout at $(API_ROOT). Run: git clone --recurse-submodules" >&2; exit 1; }
	@test -f "$(HUB_ROOT)/package.json" || { echo "Missing hub checkout at $(HUB_ROOT). Run: git clone --recurse-submodules" >&2; exit 1; }
	@test -f "$(PIPELINE_ROOT)/source/metadata.json" || { echo "Missing English tree at $(PIPELINE_ROOT)/source. Run: make submodules" >&2; exit 1; }

init: check-docker submodules
	@chmod +x make/*.sh stack/db/postgres/initdb/*.sh
	@./make/init-env.sh
	@$(STACK_MAKE) -C $(POSTGRES_DIR) env
	@$(STACK_MAKE) -C $(REDIS_DIR) env
	@$(STACK_MAKE) -C $(API_DIR) env
	@$(STACK_MAKE) -C $(HUB_DIR) env
	@$(STACK_MAKE) -C $(EDGE_DIR) env
	@echo "Lab environments are ready."

env-check:
	@test -f "$(SHARED_ENV_FILE)" || { echo "Run make init first." >&2; exit 1; }
	@grep -q '^POSTGRES_PASSWORD=.\+' "$(SHARED_ENV_FILE)" || { echo "POSTGRES_PASSWORD is empty" >&2; exit 1; }

network: check-docker
	@$(PROJECT_NAME_ENV) ./make/ensure-networks.sh

validate: init network check-siblings
	@$(STACK_MAKE) -C $(POSTGRES_DIR) validate
	@$(STACK_MAKE) -C $(REDIS_DIR) validate
	@$(STACK_MAKE) -C $(API_DIR) validate
	@$(STACK_MAKE) -C $(HUB_DIR) validate
	@$(STACK_MAKE) -C $(EDGE_DIR) validate
	@./make/test-edge-urls.sh
	@./make/test-prod-mode.sh
	@./make/test-submodules.sh
	@echo "$(MODE) stack is valid."

validate-dev:
	@$(MAKE) validate MODE=dev

up: validate
	@set -e; for target in $(DEFAULT_UP_TARGETS); do \
		$(MAKE) $$target MODE=$(MODE); \
	done
	@echo "Lab is up. Hub $$(sed -n 's/^HUB_PUBLIC_URL=//p' $(SHARED_ENV_FILE))  API $$(sed -n 's/^API_PUBLIC_URL=//p' $(SHARED_ENV_FILE))"
	@echo "Next: make seed && make verify && make review"

down:
	@set -e; for target in $(DEFAULT_DOWN_TARGETS); do \
		$(MAKE) $$target MODE=$(MODE) || true; \
	done

restart: down up

destroy:
	@$(PROJECT_NAME_ENV) CONFIRM=$(CONFIRM) ./make/destroy.sh

ps:
	@$(STACK_MAKE) -C $(POSTGRES_DIR) ps
	@$(STACK_MAKE) -C $(REDIS_DIR) ps
	@$(STACK_MAKE) -C $(API_DIR) ps
	@$(STACK_MAKE) -C $(HUB_DIR) ps
	@$(STACK_MAKE) -C $(EDGE_DIR) ps

logs:
	@test -n "$(STACK)" || { echo "Usage: make logs STACK=api SERVICE=api" >&2; exit 1; }
	@$(STACK_MAKE) -C stack/$(STACK) logs SERVICE=$(SERVICE)

postgres-up:
	@$(STACK_MAKE) -C $(POSTGRES_DIR) up
postgres-down:
	@$(STACK_MAKE) -C $(POSTGRES_DIR) down
redis-up:
	@$(STACK_MAKE) -C $(REDIS_DIR) up
redis-down:
	@$(STACK_MAKE) -C $(REDIS_DIR) down
api-up:
	@$(STACK_MAKE) -C $(API_DIR) up
api-down:
	@$(STACK_MAKE) -C $(API_DIR) down
hub-up:
	@$(STACK_MAKE) -C $(HUB_DIR) up
hub-down:
	@$(STACK_MAKE) -C $(HUB_DIR) down
edge-up:
	@$(STACK_MAKE) -C $(EDGE_DIR) up
edge-down:
	@$(STACK_MAKE) -C $(EDGE_DIR) down

seed: env-check check-siblings
	@./make/seed.sh

seed-lang: env-check check-siblings
	@test -n "$(L)" || { echo "Usage: make seed-lang L=es" >&2; exit 1; }
	@./make/seed.sh "$(L)"

verify:
	@./make/verify.sh

review:
	@./make/review.sh
