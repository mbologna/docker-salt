# docker-salt — common developer tasks
#
# Usage: make <target>
.DEFAULT_GOAL := help

IMAGE_MASTER ?= mbologna/saltstack-master
IMAGE_MINION ?= mbologna/saltstack-minion

.PHONY: help build build-master build-minion up down logs test lint clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

build: build-master build-minion ## Build both images

build-master: ## Build the saltstack-master image
	docker build -f Dockerfile-master -t $(IMAGE_MASTER) .

build-minion: ## Build the saltstack-minion image
	docker build -f Dockerfile-minion -t $(IMAGE_MINION) .

up: ## Start the stack (master + minion) in the background
	docker compose up -d --build

down: ## Stop the stack and remove volumes
	docker compose down -v --remove-orphans

logs: ## Follow the stack logs
	docker compose logs -f

test: ## Run the end-to-end integration test
	./scripts/integration-test.sh

lint: ## Lint Dockerfiles, shell scripts and workflow YAML (requires hadolint/shellcheck/yamllint)
	hadolint --failure-threshold error Dockerfile-master Dockerfile-minion
	shellcheck entrypoint-master.sh scripts/integration-test.sh
	yamllint .github/workflows/ docker-compose.yml

clean: down ## Alias for 'down'
