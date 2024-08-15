GLEAM := $(shell which gleam)

.PHONY: test

all: build

deps:
	$(GLEAM) deps download

test: deps
	$(GLEAM) test -t erlang

build: deps
	$(GLEAM) build -t erlang

check-format:
	$(GLEAM) format --check src test

package: build
	$(GLEAM) export erlang-shipment
