# Zig SDK Examples

Example plugins demonstrating the qcontrol Zig SDK for file operation filtering.

## Plugins

| Plugin | Description |
|--------|-------------|
| file-logger | Logs all file operations to a log file |
| access-control | Blocks access to `/tmp/secret*` paths |
| byte-counter | Counts bytes read/written per file |
| content-filter | Redacts sensitive data in `.txt`/`.log` files |
| text-transform | Transforms text based on file extension |

## Building

```bash
make build   # Build all plugins (.so for dynamic loading)
make dist    # Build all plugins (.o for bundling)
make clean   # Remove all built plugins
```

Each plugin outputs to its `zig-out/` directory:
- **Shared library** — `zig-out/lib/lib<name>.so`
- **Object file** — `zig-out/lib/<name>.o` (for bundling)

## Usage

```bash
ARCH=$(uname -m)-$(uname -s | tr A-Z a-z)

# Single plugin
QCONTROL_PLUGINS=./file-logger/dist/file-logger-$ARCH.so qcontrol wrap -- ls -la

# Multiple plugins
QCONTROL_PLUGINS=./file-logger/dist/file-logger-$ARCH.so,./access-control/dist/access-control-$ARCH.so \
  qcontrol wrap -- cat /tmp/secret_test.txt
```

## Bundling

```bash
# Build plugins as object files
make dist

# Bundle using config file
qcontrol bundle --config bundle.toml
# Creates: zig-plugins.so

# Use the bundle
qcontrol wrap --bundle zig-plugins.so -- ./target_app
```

## Testing

```bash
# Run the test script with plugins
qcontrol wrap --bundle zig-plugins.so -- ./test-file-ops.sh

# Check log output
cat /tmp/qcontrol.log
```

## Writing Plugins

See [file-logger/src/main.zig](file-logger/src/main.zig) for a complete example.

```zig
const std = @import("std");
const qcontrol = @import("qcontrol");

fn onFileOpen(ev: *qcontrol.file.OpenEvent) qcontrol.file.OpenResult {
    std.debug.print("open({s}) = {d}\n", .{ ev.path(), ev.result() });
    return .pass;  // or .block
}

comptime {
    qcontrol.exportPlugin(.{
        .name = "my_plugin",
        .on_file_open = onFileOpen,
    });
}
```

Add the SDK as a dependency in `build.zig.zon`:
```zig
.dependencies = .{
    .qcontrol = .{ .path = "../.." },
},
```

Import the SDK module in `build.zig`:
```zig
const qcontrol_dep = b.dependency("qcontrol", .{
    .target = target,
    .optimize = optimize,
});
const qcontrol_mod = qcontrol_dep.module("qcontrol");
my_plugin.root_module.addImport("qcontrol", qcontrol_mod);
```
