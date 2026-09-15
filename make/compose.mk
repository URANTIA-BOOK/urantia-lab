include $(dir $(lastword $(MAKEFILE_LIST)))project.mk

DOCKER_COMPOSE ?= docker compose
MODE ?= dev

STACK_NAME ?= unnamed
ENV_FILE ?= .env
ENV_EXAMPLE ?= .env.example
DEV_ENV_FILE ?= .env.dev
DEV_ENV_EXAMPLE ?= .env.dev.example
COMPOSE_FILE ?= docker-compose.yml
DEV_COMPOSE_FILE ?= docker-compose.dev.yml
BUILD ?= false
SERVICES ?=
MANAGEMENT_SERVICES ?=
ALL_PROFILES ?=
COMMAND_PREFIX ?= make

ACTIVE_ENV_FILE := $(ENV_FILE)
COMPOSE_FILES := -f $(COMPOSE_FILE)

ifeq ($(MODE),dev)
WAIT_TIMEOUT ?= 240
ifneq ($(wildcard $(DEV_ENV_EXAMPLE)),)
ACTIVE_ENV_FILE := $(DEV_ENV_FILE)
endif
ifneq ($(wildcard $(DEV_COMPOSE_FILE)),)
COMPOSE_FILES += -f $(DEV_COMPOSE_FILE)
endif
else
WAIT_TIMEOUT ?= 60
endif

COMPOSE := COMPOSE_PROJECT_NAME=$(PROJECT_NAME) COMPOSE_IGNORE_ORPHANS=true \
	API_ROOT=$(API_ROOT) HUB_ROOT=$(HUB_ROOT) PIPELINE_ROOT=$(PIPELINE_ROOT) \
	SHARED_ENV_FILE=$(SHARED_ENV_FILE) \
	$(DOCKER_COMPOSE) \
	--project-name $(PROJECT_NAME) \
	--env-file $(ACTIVE_ENV_FILE) \
	--env-file $(SHARED_ENV_FILE) \
	$(COMPOSE_FILES)
ALL_PROFILE_ARGS = $(foreach profile,$(ALL_PROFILES),--profile $(profile))

PROJECT_NAME_ENV := PROJECT_NAME_OVERRIDE=$(PROJECT_NAME_OVERRIDE) \
	PROJECT_NAME=$(if $(PROJECT_NAME_OVERRIDE),$(PROJECT_NAME),) \
	SHARED_ENV_FILE=$(SHARED_ENV_FILE)

.PHONY: help help-common help-extra env network validate build up down restart ps logs config \
	up-all down-all management-up management-down

help: help-common help-extra

help-common:
	@echo "$(STACK_NAME) stack ($(MODE) mode)"
	@echo "  make env                 Create missing environment files"
	@echo "  make validate MODE=dev   Validate the selected Compose model"
	@echo "  make up MODE=dev         Start the selected Compose model"
	@echo "  make down MODE=dev       Stop the selected Compose model"
	@echo "  make ps                  Show stack containers"
	@echo "  make logs SERVICE=name   Follow stack logs"

help-extra:

env:
	@if [ ! -f "$(SHARED_ENV_FILE)" ]; then cp "$(SHARED_ENV_EXAMPLE)" "$(SHARED_ENV_FILE)"; echo "created $(SHARED_ENV_FILE)"; else echo "exists $(SHARED_ENV_FILE)"; fi
	@if [ ! -f "$(ENV_FILE)" ]; then cp "$(ENV_EXAMPLE)" "$(ENV_FILE)"; echo "created $(ENV_FILE)"; else echo "exists $(ENV_FILE)"; fi
	@if [ -f "$(DEV_ENV_EXAMPLE)" ] && [ ! -f "$(DEV_ENV_FILE)" ]; then cp "$(DEV_ENV_EXAMPLE)" "$(DEV_ENV_FILE)"; echo "created $(DEV_ENV_FILE)"; fi
	@SHARED_ENV_FILE="$(SHARED_ENV_FILE)" "$(REPOSITORY_ROOT)/make/stamp-project-name.sh" "$(ENV_FILE)" "$(DEV_ENV_FILE)"
	@SHARED_ENV_FILE="$(SHARED_ENV_FILE)" "$(REPOSITORY_ROOT)/make/stamp-edge-urls.sh" "$(ENV_FILE)" "$(DEV_ENV_FILE)"

network:
	@$(PROJECT_NAME_ENV) "$(REPOSITORY_ROOT)/make/ensure-networks.sh"

validate: env network
	@$(COMPOSE) config --quiet
	@echo "$(STACK_NAME) ($(MODE)) is valid."

config: env
	@$(COMPOSE) config

build: env
	@if [ "$(BUILD)" = "true" ]; then $(COMPOSE) build --quiet $(SERVICES); fi

up: env network build
	@$(COMPOSE) up -d --wait --wait-timeout $(WAIT_TIMEOUT) --quiet-pull $(SERVICES)

up-all: env network
	@if [ "$(BUILD)" = "true" ]; then $(COMPOSE) $(ALL_PROFILE_ARGS) build --quiet; fi
	@$(COMPOSE) $(ALL_PROFILE_ARGS) up -d --wait --wait-timeout $(WAIT_TIMEOUT) --quiet-pull

management-up: env network
	@test -n "$(MANAGEMENT_SERVICES)" || { echo "$(STACK_NAME) has no management services." >&2; exit 1; }
	@$(COMPOSE) --profile management up -d --wait --wait-timeout $(WAIT_TIMEOUT) --quiet-pull $(MANAGEMENT_SERVICES)

management-down: env
	@test -n "$(MANAGEMENT_SERVICES)" || { echo "$(STACK_NAME) has no management services." >&2; exit 1; }
	@$(COMPOSE) --profile management stop $(MANAGEMENT_SERVICES)
	@$(COMPOSE) --profile management rm -f $(MANAGEMENT_SERVICES)

down: env
	@$(COMPOSE) down

down-all: env
	@$(COMPOSE) $(ALL_PROFILE_ARGS) down

restart: down up

ps: env
	@$(COMPOSE) ps

logs: env
	@$(COMPOSE) logs -f $(SERVICE)
