# text-transform plugin Makefile
#
# Build:   make build  (shared library for dynamic loading)
# Dist:    make dist   (object file for bundling)
# Clean:   make clean

NAME := text-transform
ARCH := $(shell uname -m | sed 's/^arm64$$/aarch64/')-$(shell uname -s | tr A-Z a-z | sed 's/^darwin$$/macos/')
DIST := dist
SHLIB_EXT := $(if $(filter Darwin,$(shell uname -s)),dylib,so)

# Zig library names use underscores
LIB_NAME := text_transform

.PHONY: all build dist clean

all: build

build:
	zig build -Doptimize=ReleaseFast
	@mkdir -p $(DIST)
	cp zig-out/lib/lib$(LIB_NAME).$(SHLIB_EXT) $(DIST)/$(NAME)-$(ARCH).$(SHLIB_EXT)

dist:
	zig build -Doptimize=ReleaseFast
	@mkdir -p $(DIST)
	cp zig-out/lib/$(LIB_NAME).o $(DIST)/$(NAME)-$(ARCH).o

clean:
	rm -rf zig-out .zig-cache $(DIST)
