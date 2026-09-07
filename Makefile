GLEAM := $(shell command -v gleam)
DOCKER_HUB_REPOSITORY ?= massix86/gleeter
DOCKER_PLATFORM ?= linux/amd64

all: build

.PHONY: deps
deps:
	$(GLEAM) deps download

.PHONY: test
test: deps
	$(GLEAM) test -t erlang

.PHONY: test-docker
test-docker:
	cd docker-test && \
	docker compose down && \
	docker compose up --build

.PHONY: build
build: deps
	$(GLEAM) build -t erlang

.PHONY: check-format
check-format:
	$(GLEAM) format --check src test

.PHONY: package
package: build
	$(GLEAM) export erlang-shipment

.PHONY: serve
serve: build
	GLEETER_DEBUG=1 $(GLEAM) run -- serve 8080 comics

.PHONY: docker
docker:
	nix build .#version-file
	docker build --platform $(DOCKER_PLATFORM) -t $(DOCKER_HUB_REPOSITORY):$$(< result) .
	docker tag $(DOCKER_HUB_REPOSITORY):$$(< result) $(DOCKER_HUB_REPOSITORY):latest

.PHONY: dockerdo
dockerdo:
	nix build .#version-file
	docker build \
		--platform $(DOCKER_PLATFORM) \
		--file docker-digitalocean/Dockerfile \
		--build-arg baseVersion=$$(< result) \
		--tag $(DOCKER_HUB_REPOSITORY):do-$$(< result) docker-digitalocean/
	docker tag $(DOCKER_HUB_REPOSITORY):do-$$(< result) $(DOCKER_HUB_REPOSITORY):do-latest

.PHONY: precalc-packages
precalc-packages:
	if test -d build; then rm -fr build; fi
	if test -d out; then rm -fr out; fi
	gleam deps download
	awk '/^\[/ { sec++; print sprintf("%03d0", sec) "|" $$0; next } NF { print sprintf("%03d1", sec) "|" $$0 }' build/packages/packages.toml | sort | sed 's/^[0-9][0-9][0-9][01]|//' > packages.toml.canon && mv packages.toml.canon build/packages/packages.toml
	mkdir out
	cp --recursive build out/
	nix-hash --type sha256 --sri out/ > out.hash
	rm -fr out
	rm -fr build

.PHONY: fix-flake
fix-flake: precalc-packages
	current_hash="$(shell cat flake.nix | grep gleamPackagesHash | head -1 | cut -d= -f2- | tr -d '"; ')"; \
	new_hash="$(shell cat out.hash)"; \
	if [[ "$$current_hash" != "$$new_hash" ]]; then \
    sed -i "s|$$current_hash|$$new_hash|" flake.nix; \
	fi

nix: fix-flake
	nix build . --print-build-logs
