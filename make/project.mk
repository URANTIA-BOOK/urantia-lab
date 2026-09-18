# Compose project identity.
# COMPOSE_PROJECT_NAME in .env.shared is the persisted source of truth.
# PROJECT_NAME is the make-time overwrite door.
ifeq ($(COMPOSE_PROJECT_MK_INCLUDED),)
COMPOSE_PROJECT_MK_INCLUDED := 1

REPOSITORY_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
SHARED_ENV_FILE ?= $(REPOSITORY_ROOT)/.env.shared
SHARED_ENV_EXAMPLE ?= $(REPOSITORY_ROOT)/.env.shared.example
DEFAULT_COMPOSE_PROJECT_NAME := urantialab
export SHARED_ENV_FILE
export SHARED_ENV_EXAMPLE
export COMPOSE_IGNORE_ORPHANS := true

PROJECT_NAME_ORIGIN := $(origin PROJECT_NAME)

COMPOSE_PROJECT_NAME_FILE := $(shell test -f "$(SHARED_ENV_FILE)" && sed -n 's/^COMPOSE_PROJECT_NAME=//p' "$(SHARED_ENV_FILE)" | tail -n 1)

ifeq ($(filter command line environment,$(PROJECT_NAME_ORIGIN)),)
  PROJECT_NAME_OVERRIDE :=
  PROJECT_NAME := $(or $(COMPOSE_PROJECT_NAME_FILE),$(DEFAULT_COMPOSE_PROJECT_NAME))
else
  PROJECT_NAME_OVERRIDE := 1
endif

APPS_NETWORK := $(PROJECT_NAME)-apps
BACKEND_NETWORK := $(PROJECT_NAME)-backend

# Apps live in this checkout (git submodules). Override only to point at a
# different tree; do not invent a second sibling layout.
PIPELINE_ROOT ?= $(REPOSITORY_ROOT)/pipeline
API_ROOT ?= $(REPOSITORY_ROOT)/api
HUB_ROOT ?= $(REPOSITORY_ROOT)/hub
DATA_SOURCES_ROOT ?= $(REPOSITORY_ROOT)/data-sources
endif
