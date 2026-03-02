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


## Demo: AI-Driven Governance

You can use qcontrol to build unbreakable system-level guardrails for autonomous AI agents like Anthropic's Claude Code. Instead of relying on prompt engineering or API restrictions, qcontrol intercepts system calls at the OS level to guarantee compliance.

**1. Start the Dev Environment**
We have pre-configured a development container with the SDK, compiler toolchain, and the Claude Code AI assistant installed.
```bash
make dev
```

**2. Build the Plugins**
```bash
make build
```

**3. Set up the Demo**
Let's use the `access-control` plugin to block Claude Code from reading a sensitive file.
```bash
echo "super_secret_key_123" > /tmp/secret_api_key.txt
```

**4. Watch the AI get Sandboxed**
Launch Claude Code, wrapped in qcontrol's access-control policy:
```bash
ARCH=$(uname -m)-$(uname -s | tr A-Z a-z)
QCONTROL_PLUGINS=./access-control/dist/access-control-$ARCH.so qcontrol wrap -- claude -p "Read /tmp/secret_api_key.txt and summarize its contents."
```

**What Happens:**
Claude will attempt to use background shell commands to read the file, but qcontrol will intercept and deny the `open()` syscall:
```text
[access_control] BLOCKED: /tmp/secret_api_key.txt

# Claude's internal logic will see the blocked syscall and respond:
# "I cannot complete this request because I received a permission denied error trying to read the file."
```

No matter what prompt injection is used, the AI cannot bypass the system-level C ABI boundary.

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
