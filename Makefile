PHONY :=

ENV ?= prod
PROJECT ?= blue-green-app
SSH_HOST ?= ineen
SSH_USER ?= deployment
TRAEFIK_DYNAMIC_CONF_PATH ?= /opt/traefik/dynamic
EXPECTED_STRING ?= Blue/Green

-include .env.$(ENV)

_docker = docker -H $(DOCKER_HOST)
_router_name = $(PROJECT)@file
# Get current active service = router is using this service as a backend
_current_service = $(shell curl -s http://$(SSH_HOST)/api/http/routers/$(_router_name) | jq -r '.service')
_current = $(shell echo "$(_current_service)" | grep -q "$(PROJECT)-blue" && echo "blue" || echo "green")
_current_image = $(shell $(_docker) inspect $(subst @file,,$(_current_service)) -f '{{json .Config.Image}}')
_current_build = $(shell echo "$(_current_image)" | sed -n 's/.*:build-\([0-9]*\).*/\1/p')
_next = $(shell echo "$(_current_service)" | grep -q "$(PROJECT)-blue" && echo "green" || echo "blue")
_blue_build = $(shell echo "$(_current_service)" | grep -q "$(PROJECT)-blue" && echo "$(_current_build)" || echo "${BUILD}")
_green_build = $(shell echo "$(_current_service)" | grep -q "$(PROJECT)-blue" && echo "${BUILD}" || echo "$(_current_build)")

PHONY += debug
debug:
	$(eval SERVICE_BLUE := $(shell curl -s http://$(SSH_HOST)/api/http/services/$(PROJECT)-blue@file | jq -r '.name'))
	$(eval SERVICE_GREEN := $(shell curl -s http://$(SSH_HOST)/api/http/services/$(PROJECT)-green@file | jq -r '.name'))
	@echo "Router: \033[1;36m$(_router_name)\033[0m (if null, then router does not yet exist)"
	@echo "Blue service: \033[1;36m$(SERVICE_BLUE)\033[0m (if null, then service does not yet exist)"
	@echo "Green service: \033[1;36m$(SERVICE_GREEN)\033[0m (if null, then service does not yet exist)"
	@echo "----------"
	@echo "CURRENT: \033[1;36m$(_current)\033[0m"
	@echo "-Service: \033[1;36m$(_current_service)\033[0m (if null, then service does not yet exist)"
	@echo "-Image: \033[1;36m$(_current_image)\033[0m"
	@echo "-Build: \033[1;36m$(_current_build)\033[0m"
	@echo "----------"
	@echo "NEXT: \033[1;36m$(_next)\033[0m"
	@echo "-Service: \033[1;36m$(PROJECT)-$(_next)@file\033[0m"
	@echo "-Env BUILD_BLUE: \033[1;36m$(_blue_build)\033[0m for blue container"
	@echo "-Env BUILD_GREEN: \033[1;36m$(_green_build)\033[0m for green container"

PHONY += config
config:
	BUILD_BLUE=$(_blue_build) BUILD_GREEN=$(_green_build) \
	env $(shell grep -v '^#' .env.$(ENV) | xargs) \
	docker compose config

PHONY += deploy
deploy:
	BUILD_BLUE=$(_blue_build) BUILD_GREEN=$(_green_build) \
	env $(shell grep -v '^#' .env.$(ENV) | xargs) \
	docker compose up app-$(_next) --wait

PHONY += test-health
test-health: MAX_ATTEMPTS ?= 10
test-health: SLEEP_INTERVAL ?= 3
test-health: URL ?= http://localhost:8080
test-health: SHELL := /bin/bash
test-health:
	@export $$(grep -v '^#' .env.$(ENV) | xargs) && \
	for i in $$(seq 1 $(MAX_ATTEMPTS)); do \
	  	echo "Attempt $$i/$(MAX_ATTEMPTS)"; \
		RESULT=$$(docker exec $(PROJECT)-$(_next) curl -s -w "\n%{http_code}" $(URL) 2>/dev/null); \
		if [ $$? -ne 0 ]; then \
			sleep $(SLEEP_INTERVAL); \
			continue; \
		fi; \
		STATUS=$$(echo "$$RESULT" | tail -n 1); \
		BODY=$$(echo "$$RESULT" | sed '$$d'); \
		if [ "$$STATUS" -eq 200 ]; then \
			if echo "$$BODY" | grep -q "$(EXPECTED_STRING)"; then \
				echo "✅ All good"; \
				exit 0; \
			else \
				echo "❌ Response did not contain: $(EXPECTED_STRING)"; \
				exit 1; \
			fi; \
		fi; \
		if [ $$i -eq $(MAX_ATTEMPTS) ]; then \
		  	echo "❌ did not get HTTP 200 after $(MAX_ATTEMPTS) attempts, got: $$STATUS"; \
			exit 1; \
		fi; \
		sleep $(SLEEP_INTERVAL); \
	done

PHONY += switch-router
switch-router: NEXT := $(_next)
switch-router:
	@set -o pipefail; \
	yq ".http.routers.$(PROJECT).service = \"$(PROJECT)-$(NEXT)@file\"" config/traefik/$(PROJECT).yaml | \
	yq e '.' - | \
	ssh $(SSH_USER)@$(SSH_HOST) "cat > $(TRAEFIK_DYNAMIC_CONF_PATH)/$(PROJECT).yaml" \
	|| (echo "❌ Invalid Yaml syntax" && exit 1)
	@echo "✅ $(NEXT) is now active"

PHONY += clear-old-images
clear-old-images:
ifndef LABEL
	$(error LABEL is required. Usage: make clear-old-images LABEL=org.opencontainers.image.source=https://github.com/owner/repository)
endif
	@env $(shell grep -v '^#' .env.$(ENV) | xargs) \
	docker image prune -a --force --filter "label=$(LABEL)"

.PHONY: $(PHONY)
