# access-control plugin Makefile
#
# Build:   make build  (shared library for dynamic loading)
# Dist:    make dist   (object file for bundling)
# Clean:   make clean

NAME := access-control
ARCH := $(shell uname -m)-$(shell uname -s | tr A-Z a-z)
DIST := dist

# Zig library names use underscores
LIB_NAME := access_control

.PHONY: all build dist clean

all: build

build:
	zig build -Doptimize=ReleaseFast
	@mkdir -p $(DIST)
	cp zig-out/lib/lib$(LIB_NAME).so $(DIST)/$(NAME)-$(ARCH).so

dist:
	zig build -Doptimize=ReleaseFast
	@mkdir -p $(DIST)
	cp zig-out/lib/$(LIB_NAME).o $(DIST)/$(NAME)-$(ARCH).o

clean:
	rm -rf zig-out .zig-cache $(DIST)
