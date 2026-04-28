# http-rewrite plugin Makefile
#
# Build:   make build  (shared library for dynamic loading)
# Dist:    make dist   (object file for bundling)
# Clean:   make clean

NAME := http-rewrite
ARCH := $(shell uname -m | sed 's/^arm64$$/aarch64/')-$(shell uname -s | tr A-Z a-z | sed 's/^darwin$$/macos/')
DIST := dist
SHLIB_EXT := $(if $(filter Darwin,$(shell uname -s)),dylib,so)

.PHONY: all build dist clean

all: build

build:
	zig build
	@mkdir -p $(DIST)
	cp zig-out/lib/libhttp_rewrite.$(SHLIB_EXT) $(DIST)/$(NAME)-$(ARCH).$(SHLIB_EXT)

dist:
	zig build
	@mkdir -p $(DIST)
	cp zig-out/lib/libhttp_rewrite.$(SHLIB_EXT) $(DIST)/
	cp zig-out/lib/http_rewrite.o $(DIST)/

clean:
	rm -rf $(DIST) zig-out .zig-cache
