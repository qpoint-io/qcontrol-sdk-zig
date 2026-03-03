# Zig SDK Examples
#
# Build bundle:  make           (recommended)
# Build plugins:  make build    (shared libraries for dynamic loading)
# Build dist:  make dist        (object files for bundling)
# Clean:  make clean
# Dev container:  make dev

PLUGINS := file-logger access-control byte-counter content-filter text-transform
IMAGE_NAME := qcontrol-sdk-zig-demo

.PHONY: all bundle build dist clean docker-build dev

all: bundle

bundle:
	qcontrol bundle --config bundle.toml

build:
	@for p in $(PLUGINS); do $(MAKE) -C $$p build; done

dist:
	@for p in $(PLUGINS); do $(MAKE) -C $$p dist; done

clean:
	rm -f zig-plugins.so
	@for p in $(PLUGINS); do $(MAKE) -C $$p clean; done

docker-build:
	docker build -t $(IMAGE_NAME) -f Dockerfile ..

dev: docker-build
	docker run --rm -it $(IMAGE_NAME)
