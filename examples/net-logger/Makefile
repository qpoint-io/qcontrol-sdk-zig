.PHONY: all clean dist

all:
	zig build -Doptimize=ReleaseFast

debug:
	zig build

clean:
	rm -rf zig-out .zig-cache dist

dist: all
	mkdir -p dist
	cp zig-out/lib/libnet_logger.so dist/
	cp zig-out/lib/net_logger.o dist/
