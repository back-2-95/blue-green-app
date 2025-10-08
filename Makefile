PHONY :=

ENV ?= prod
GHA_DEPLOY_WORKFLOW ?= deploy.yml
PROJECT ?= blue-green-app
SSH_HOST ?= ineen
SSH_USER ?= deployment
TRAEFIK_API ?= http://$(SSH_HOST)/api/http
TRAEFIK_ROUTER_NAME ?= $(PROJECT)@file # Example: my-project-prod@file
TRAEFIK_DYNAMIC_CONF_PATH ?= /opt/traefik/dynamic

-include .env.$(ENV)

_docker = docker -H $(DOCKER_HOST)
# Get current active service = router is using this service as a backend
_current_service = $(shell curl -s $(TRAEFIK_API)/routers/$(TRAEFIK_ROUTER_NAME) | jq -r '.service')
#_service_blue = $(shell curl -s $(TRAEFIK_API)/services/$(PROJECT)-blue@file | jq -r '.name')
#_service_green = $(shell curl -s $(TRAEFIK_API)/services/$(PROJECT)-green@file | jq -r '.name')
_current = $(shell echo "$(_current_service)" | grep -q "$(PROJECT)-blue" && echo "blue" || echo "green")
_current_container = $(shell $(_docker) inspect $(subst @file,,$(_current_service)) -f '{{json .Config.Image}}')
_current_build = $(shell echo "$(_current_container)" | sed -n 's/.*:build-\([0-9]*\).*/\1/p')
_next = $(shell echo "$(_current_service)" | grep -q "$(PROJECT)-blue" && echo "green" || echo "blue")
_blue_build = $(shell echo "$(_current_service)" | grep -q "$(PROJECT)-blue" && echo "$(_current_build)" || echo "${BUILD}")
_green_build = $(shell echo "$(_current_service)" | grep -q "$(PROJECT)-blue" && echo "${BUILD}" || echo "$(_current_build)")

PHONY += debug
debug:
	@echo "CURRENT: \033[1;36m$(_current)\033[0m"
	@echo "Router points currently to service: \033[1;36m$(_current_service)\033[0m (if null, then router does not exist)"
	@echo "Current service: \033[1;36m$(_current_service)\033[0m (if null, then service does not exist)"
#	@echo "Blue service: \033[1;36m$(_service_blue)\033[0m (if null, then service does not exist)"
#	@echo "Green service: \033[1;36m$(_service_green)\033[0m (if null, then service does not exist)"
	@echo "Current build number: \033[1;36m$(_current_container)\033[0m"
	@echo "Next service: \033[1;36m$(PROJECT)-$(_next)@file\033[0m"
	@echo "NEXT: \033[1;36m$(_next)\033[0m"
	@echo "Env BUILD_BLUE: \033[1;36m$(_blue_build)\033[0m for blue container"
	@echo "Env BUILD_GREEN: \033[1;36m$(_green_build)\033[0m for green container"

PHONY += config
config:
	BUILD_BLUE=$(_blue_build) \
	BUILD_GREEN=$(_green_build) \
	env $(shell grep -v '^#' .env.prod | xargs) \
	docker compose config

PHONY += deploy
deploy:
	BUILD_BLUE=$(_blue_build) \
	BUILD_GREEN=$(_green_build) \
	env $(shell grep -v '^#' .env.prod | xargs) \
	docker compose up app-$(_next) --wait

PHONY += update-traefik-conf
update-traefik-conf: NEXT := $(_next)
update-traefik-conf: OUTPUT_FILE := /tmp/_dynamic.yaml
update-traefik-conf:
	@yq ".http.routers.$(PROJECT).service = \"$(PROJECT)-$(NEXT)@file\"" config/traefik/$(PROJECT).yaml > $(OUTPUT_FILE)
	@yq e '.' $(OUTPUT_FILE) >/dev/null 2>&1 && echo "✓ Valid" || (echo "✗ Invalid" && exit 1)
	@scp $(OUTPUT_FILE) $(SSH_USER)@$(SSH_HOST):$(TRAEFIK_DYNAMIC_CONF_PATH)/$(PROJECT).yaml
	@rm $(OUTPUT_FILE)

.PHONY: $(PHONY)
