PHONY :=

ENV ?= prod
GHA_DEPLOY_WORKFLOW ?= deploy.yml
PROJECT ?= blue-green-app
SSH_HOST ?= ineen
SSH_USER ?= deployment
TRAEFIK_API ?= http://$(SSH_HOST)/api/http
TRAEFIK_ROUTER_NAME ?= $(PROJECT)@file

-include .env.$(ENV)

_current_service = $(shell curl -s $(TRAEFIK_API)/routers/$(TRAEFIK_ROUTER_NAME) | jq -r '.service')
_service_blue = $(shell curl -s $(TRAEFIK_API)/services/$(PROJECT)-blue@file | jq -r '.name')
_service_green = $(shell curl -s $(TRAEFIK_API)/services/$(PROJECT)-green@file | jq -r '.name')
_latest_build = $(shell gh run list -w $(GHA_DEPLOY_WORKFLOW) -b main -L 1 --json number | jq -r '.[0].number')
_next_service = $(shell echo "$(_current_service)" | grep -q "blue" && echo "green" || echo "blue")

PHONY += debug
debug:
	@echo "Router points currently to service: \033[1;36m$(_current_service)\033[0m (if null, then router does not exist)"
	@echo "Blue service: \033[1;36m$(_service_blue)\033[0m (if null, then service does not exist)"
	@echo "Green service: \033[1;36m$(_service_green)\033[0m (if null, then service does not exist)"
	@echo "Latest build number: \033[1;36mbuild-$(_latest_build)\033[0m"
	@echo "Next service: \033[1;36m$(PROJECT)-$(_next_service)@file\033[0m"

PHONY += update-traefik-conf
update-traefik-conf: NEXT := $(_next_service)
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
