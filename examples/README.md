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


## Demo: Zero-Trust Governance

You can use qcontrol to build unbreakable system-level guardrails for *any* application—from standard Linux utilities to autonomous AI coding agents.

Instead of relying on application logic or API restrictions, qcontrol intercepts system calls at the OS level to guarantee compliance without modifying the target binary.

**1. Start the Dev Environment**
We have pre-configured a development container with the SDK, compiler toolchain, and Anthropic's Claude Code AI assistant installed.
```bash
make dev
```

**2. Build the Plugins**
```bash
make build
```

**3. Set up the Demo**
Let's use the `access-control` plugin to protect a mock API key file.
```bash
echo "super_secret_key_123" > /tmp/secret_api_key.txt
```

**4. Watch the OS block the read**
Launch the standard `cat` utility, but wrap it in qcontrol's access-control policy:
```bash
ARCH=$(uname -m)-$(uname -s | tr A-Z a-z)
QCONTROL_PLUGINS=./access-control/dist/access-control-$ARCH.so qcontrol wrap -- cat /tmp/secret_api_key.txt
```

**What Happens:**
`cat` will attempt to read the file, but qcontrol will intercept and deny the `open()` syscall at the C ABI boundary.
```text
cat: /tmp/secret_api_key.txt: Permission denied

# Check the background audit log to see the interception:
cat /tmp/qcontrol.log

[access_control.zig] BLOCKED: /tmp/secret_api_key.txt
```

### Next Step: Sandboxing Autonomous AI

Because qcontrol works at the system level, you can wrap autonomous AI tools to create unbreakable guardrails against prompt injections. The dev container has Anthropic's Claude Code CLI pre-installed to test this.

If you have an Anthropic Console account, you can try sandboxing the AI:

```bash
# 1. Authenticate the AI
claude auth login

# 2. Command the AI to read the secret file, but wrap it in our policy
QCONTROL_PLUGINS=./access-control/dist/access-control-$ARCH.so qcontrol wrap -- claude -p "Read /tmp/secret_api_key.txt and summarize its contents."
```

Claude will hit the system-level block, realize it is sandboxed, and gracefully respond: *"I cannot complete this request because I received a permission denied error trying to read the file."*


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
