PHONY :=

ENV ?= prod
GHA_DEPLOY_WORKFLOW ?= deploy.yml
PROJECT ?= blue-green-app
SSH_HOST ?= ineen
SSH_USER ?= deployment
TRAEFIK_ROUTER_NAME ?= $(PROJECT)@file

-include .env.$(ENV)

_current_service = $(shell curl -s http://$(SSH_HOST)/api/http/routers/$(TRAEFIK_ROUTER_NAME) | jq -r '.service')
_service_blue = $(shell curl -s http://$(SSH_HOST)/api/http/services/$(PROJECT)-blue@file | jq -r '.name')
_service_green = $(shell curl -s http://$(SSH_HOST)/api/http/services/$(PROJECT)-green@file | jq -r '.name')
_latest_build = $(shell gh run list -w $(GHA_DEPLOY_WORKFLOW) -b main -L 1 --json number | jq -r '.[0].number')

PHONY += debug
debug:
	@echo "Router points currently to service: $(_current_service) (if null, then router does not exist)"
	@echo "Blue service: $(_service_blue) (if null, then service does not exist)"
	@echo "Green service: $(_service_green) (if null, then service does not exist)"
	@echo "latest build number: $(_latest_build)"

PHONY += update-traefik-conf
update-traefik-conf: NEXT := blue
update-traefik-conf: OUTPUT_FILE := /tmp/_dynamic.yaml
update-traefik-conf:
	@yq ".http.routers.$(PROJECT).service = \"$(PROJECT)-$(NEXT)@file\"" config/traefik/$(PROJECT).yaml > $(OUTPUT_FILE)
	@yq e '.' $(OUTPUT_FILE) >/dev/null 2>&1 && echo "✓ Valid" || (echo "✗ Invalid" && exit 1)
	@scp $(OUTPUT_FILE) $(SSH_USER)@$(SSH_HOST):/opt/traefik/dynamic/$(PROJECT).yaml
	@rm $(OUTPUT_FILE)

PHONY += --get-latest-build
--get-latest-build:
	$(eval BUILD := $(shell gh run list -w deploy.yml -b main -L 1 -s success --json number | jq '.[0].number'))

PHONY += --get-current-build-%
--get-current-build-%:
	$(eval BUILD := $(shell $(call _docker,$*) inspect -f '{{ index .Config.Labels "gha.build" }}' $(PROJECT)-$*))

.PHONY: $(PHONY)
