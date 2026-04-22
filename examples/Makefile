# Zig SDK Examples
#
# Build bundle:  make                (recommended)
# Build plugins:  make build         (shared libraries for dynamic loading)
# Build file/net/exec:  make build-file | build-net | build-exec
# Build bundles by type:  make bundle-file | bundle-net | bundle-exec
# Build dist:  make dist             (object files for bundling)
# Clean:  make clean
# Dev container:  make dev

FILE_PLUGINS := file-logger access-control byte-counter content-filter text-transform
EXEC_PLUGINS := exec-logger
NET_PLUGINS := net-logger net-transform http-access-logs
PLUGINS := $(FILE_PLUGINS) $(EXEC_PLUGINS) $(NET_PLUGINS)
IMAGE_NAME := qcontrol-sdk-zig-demo

.PHONY: all bundle bundle-file bundle-exec bundle-net build build-file build-exec build-net dist dist-file dist-exec dist-net clean docker-build dev

all: bundle

bundle:
	qcontrol bundle --config bundle.toml

bundle-file:
	qcontrol bundle --config bundle-file.toml

bundle-exec:
	qcontrol bundle --config bundle-exec.toml

bundle-net:
	qcontrol bundle --config bundle-net.toml

build:
	@for p in $(PLUGINS); do $(MAKE) -C $$p build; done

build-file:
	@for p in $(FILE_PLUGINS); do $(MAKE) -C $$p build; done

build-exec:
	@for p in $(EXEC_PLUGINS); do $(MAKE) -C $$p build; done

build-net:
	@for p in $(NET_PLUGINS); do $(MAKE) -C $$p build; done

dist:
	@for p in $(PLUGINS); do $(MAKE) -C $$p dist; done

dist-file:
	@for p in $(FILE_PLUGINS); do $(MAKE) -C $$p dist; done

dist-exec:
	@for p in $(EXEC_PLUGINS); do $(MAKE) -C $$p dist; done

dist-net:
	@for p in $(NET_PLUGINS); do $(MAKE) -C $$p dist; done

clean:
	rm -f zig-plugins.so zig-file-plugins.so zig-exec-plugins.so zig-net-plugins.so
	@for p in $(PLUGINS); do $(MAKE) -C $$p clean; done

docker-build:
	docker build -t $(IMAGE_NAME) -f Dockerfile ..

dev: docker-build
	docker run --rm -it $(IMAGE_NAME)
