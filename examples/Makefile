# Zig SDK Examples
#
# Build all plugins:  make build
# Build dist artifacts:  make dist
# Clean:  make clean
# Dev container:  make dev
#
# Each plugin is in its own directory with its own Makefile.
# Plugins output to their zig-out/ directories:
#   - build:  lib<name>.so  (shared library for dynamic loading)
#   - dist:   lib/<name>.o  (object file for bundling)

PLUGINS := file-logger access-control byte-counter content-filter text-transform
IMAGE_NAME := qcontrol-sdk-zig-demo

.PHONY: all build dist clean docker-build dev

all: build

build:
	@for p in $(PLUGINS); do $(MAKE) -C $$p build; done

dist:
	@for p in $(PLUGINS); do $(MAKE) -C $$p dist; done

clean:
	@for p in $(PLUGINS); do $(MAKE) -C $$p clean; done

docker-build:
	docker build -t $(IMAGE_NAME) -f Dockerfile ..

dev: docker-build
	docker run --rm -it $(IMAGE_NAME)
