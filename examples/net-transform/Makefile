.PHONY: all build clean dist

ARCH := $(shell uname -m | sed 's/^arm64$$/aarch64/')-$(shell uname -s | tr A-Z a-z | sed 's/^darwin$$/macos/')
SHLIB_EXT := $(if $(filter Darwin,$(shell uname -s)),dylib,so)

all:
	zig build -Doptimize=ReleaseFast

build: all
	mkdir -p dist
	cp zig-out/lib/libnet_transform.$(SHLIB_EXT) dist/net-transform-$(ARCH).$(SHLIB_EXT)

debug:
	zig build

clean:
	rm -rf zig-out .zig-cache dist

dist: all
	mkdir -p dist
	cp zig-out/lib/libnet_transform.$(SHLIB_EXT) dist/
	cp zig-out/lib/net_transform.o dist/
