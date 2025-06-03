GLEAM := $(shell command -v gleam)
DOCKER_HUB_REPOSITORY ?= massix86/gleeter
DOCKER_PLATFORM ?= linux/amd64

.PHONY: test

all: build

.PHONY: deps
deps:
	$(GLEAM) deps download

.PHONY: test
test: deps
	$(GLEAM) test -t erlang

.PHONY: build
build: deps
	$(GLEAM) build -t erlang

.PHONY: check-format
check-format:
	$(GLEAM) format --check src test

.PHONY: package
package: build
	$(GLEAM) export erlang-shipment

.PHONY: docker
docker:
	nix build .#version-file
	docker build --platform $(DOCKER_PLATFORM) -t $(DOCKER_HUB_REPOSITORY):`cat result` .
	docker tag $(DOCKER_HUB_REPOSITORY):`cat result` $(DOCKER_HUB_REPOSITORY):latest

.PHONY: precalc-packages
precalc-packages:
	if test -d build; then rm -fr build; fi
	if test -d out; then rm -fr out; fi
	gleam deps download
	grep -v '\[packages\]' build/packages/packages.toml | sort > packages.toml
	echo -e "[packages]\n" > build/packages/packages.toml
	cat packages.toml >> build/packages/packages.toml
	rm packages.toml
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
