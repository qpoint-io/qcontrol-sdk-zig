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
| exec-logger | Logs all exec operations (v1 - not yet implemented) |
| net-logger | Logs all network operations (v1 - not yet implemented) |

## Quick Start

```bash
make                  # Build all plugins into zig-plugins.so
qcontrol wrap --bundle ./zig-plugins.so -- ./your-app
```

## Demo: Zero-Trust Governance

Use qcontrol to build unbreakable system-level guardrails for *any* application—from standard Linux utilities to autonomous AI coding agents.

Instead of relying on application logic or API restrictions, qcontrol intercepts system calls at the OS level to guarantee compliance without modifying the target binary.

**1. Start the Dev Environment**

We have pre-configured a development container with the SDK, compiler toolchain, and Anthropic's Claude Code AI assistant installed.
```bash
make dev
```

**2. Build the Plugins**
```bash
make
```

**3. Set up the Demo**

Let's use the `access-control` plugin to protect a mock API key file.
```bash
echo "super_secret_key_123" > /tmp/secret_api_key.txt
```

**4. Watch the OS block the read**

Launch the standard `cat` utility, but wrap it in qcontrol's access-control policy:
```bash
qcontrol wrap --bundle ./zig-plugins.so -- cat /tmp/secret_api_key.txt
```

**What Happens:**
`cat` will attempt to read the file, but qcontrol will intercept and deny the `open()` syscall at the C ABI boundary.
```text
cat: /tmp/secret_api_key.txt
```

Check the audit log to see the interception:
```bash
cat /tmp/qcontrol.log
```
```text
[access_control.zig] BLOCKED: /tmp/secret_api_key.txt
```

### Next Step: Sandboxing Autonomous AI

Because qcontrol works at the system level, you can wrap autonomous AI tools to create unbreakable guardrails against prompt injections. The dev container has Anthropic's Claude Code CLI pre-installed to test this.

If you have an Anthropic Console account, you can try sandboxing the AI:

```bash
# 1. Authenticate the AI
claude auth login

# 2. Command the AI to read the secret file, but wrap it in our policy
qcontrol wrap --bundle ./zig-plugins.so -- claude -p "Read /tmp/secret_api_key.txt and summarize its contents."
```

Claude will hit the system-level block, realize it is sandboxed, and gracefully respond: *"I cannot complete this request because I received a permission denied error trying to read the file."*

## Testing

```bash
# Run the test script with plugins
qcontrol wrap --bundle ./zig-plugins.so -- ./test-file-ops.sh

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

## Advanced: Dynamic Loading

For development or when you need to load individual plugins without bundling:

```bash
# Build shared libraries
make build

# Load plugins dynamically
QCONTROL_PLUGINS=./file-logger/zig-out/lib/libfile-logger.so qcontrol wrap -- ls -la

# Multiple plugins (comma-separated)
QCONTROL_PLUGINS=./file-logger/zig-out/lib/libfile-logger.so,./access-control/zig-out/lib/libaccess-control.so \
  qcontrol wrap -- cat /tmp/secret_test.txt
```
