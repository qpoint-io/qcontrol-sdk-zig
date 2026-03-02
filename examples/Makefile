# Zig SDK Examples
#
# Build all plugins:  make build
# Build dist artifacts:  make dist
# Clean:  make clean
#
# Each plugin is in its own directory with its own Makefile.
# Plugins output to their zig-out/ directories:
#   - build:  lib<name>.so  (shared library for dynamic loading)
#   - dist:   lib/<name>.o  (object file for bundling)

PLUGINS := file-logger access-control byte-counter content-filter text-transform

.PHONY: all build dist clean

all: build

build:
	@for p in $(PLUGINS); do $(MAKE) -C $$p build; done

dist:
	@for p in $(PLUGINS); do $(MAKE) -C $$p dist; done

clean:
	@for p in $(PLUGINS); do $(MAKE) -C $$p clean; done
