# qcontrol Zig SDK

Idiomatic Zig bindings for writing qcontrol plugins that intercept file, exec, and network operations.

## Table of Contents

- [Introduction](#introduction)
- [Quick Start](#quick-start)
- [Examples](#examples)
- [Building Plugins](#building-plugins)
  - [Project Setup](#project-setup)
  - [Plugin Structure](#plugin-structure)
  - [Building](#building)
  - [Using Plugins](#using-plugins)
- [Bundling Plugins](#bundling-plugins)
  - [Bundle Configuration](#bundle-configuration)
  - [Creating a Bundle](#creating-a-bundle)
  - [Using Bundles](#using-bundles)
- [API Reference](#api-reference)
  - [Plugin Lifecycle](#plugin-lifecycle)
  - [Logger Utility](#logger-utility)
- [File Operations](#file-operations)
  - [Callbacks](#file-callbacks)
  - [Events](#file-events)
  - [Actions](#file-actions)
  - [Sessions and Transforms](#sessions-and-transforms)
  - [Buffer API](#buffer-api)
  - [Patterns](#patterns)
- [Exec Operations](#exec-operations)
  - [Callbacks](#exec-callbacks)
  - [Events](#exec-events)
  - [Actions](#exec-actions)
  - [Sessions](#exec-sessions)
- [Network Operations](#network-operations)
  - [Callbacks](#network-callbacks)
  - [Events](#network-events)
  - [Actions](#network-actions)
  - [Sessions](#network-sessions)
  - [Context](#network-context)
- [Environment Variables](#environment-variables)
- [License](#license)

## Introduction

**qcontrol** is a CLI tool for observing and controlling applications via native function hooking. The Zig SDK provides idiomatic Zig bindings for writing plugins that can:

- **File operations**: Intercept open, read, write, and close syscalls
- **Exec operations** (v1): Intercept process spawning and I/O (not yet implemented in agent)
- **Network operations** (v1): Intercept connections, sends, and receives (not yet implemented in agent)

Plugins can observe operations, block them, or transform data in transit. All C interop is handled internally - you work with native Zig types.

## Quick Start

Create a minimal plugin that logs file opens:

```zig
const std = @import("std");
const qcontrol = @import("qcontrol");

fn onFileOpen(ev: *qcontrol.file.OpenEvent) qcontrol.file.OpenResult {
    std.debug.print("open: {s}\n", .{ev.path()});
    return .pass;
}

comptime {
    qcontrol.exportPlugin(.{
        .name = "hello-plugin",
        .on_file_open = onFileOpen,
    });
}
```

Build and run:

```bash
zig build -Doptimize=ReleaseFast
qcontrol wrap --plugins ./zig-out/lib/libhello_plugin.so -- cat /etc/passwd
```

## Examples

| Plugin | Description | Demonstrates |
|--------|-------------|--------------|
| [file-logger](examples/file-logger/) | Logs all file operations | Basic callbacks, Logger utility |
| [access-control](examples/access-control/) | Blocks `/tmp/secret*` paths | Blocking with `.block` |
| [byte-counter](examples/byte-counter/) | Tracks bytes read/written | State tracking with `.state` |
| [content-filter](examples/content-filter/) | Redacts sensitive data | Session with RwConfig patterns |
| [text-transform](examples/text-transform/) | Custom buffer manipulation | Session with transform function |
| [exec-logger](examples/exec-logger/) | Logs exec operations | v1 exec API |
| [net-logger](examples/net-logger/) | Logs network operations | v1 network API |

## Building Plugins

### Project Setup

Create the following directory structure:

```
my-plugin/
  build.zig
  build.zig.zon
  Makefile
  src/
    main.zig
```

**build.zig** - Build configuration:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Auto-detect local SDK (for development in monorepo)
    const local_sdk_path = b.path("../../build.zig").getPath(b);
    const use_local_sdk = std.fs.cwd().access(local_sdk_path, .{}) != error.FileNotFound;

    const qcontrol_mod = if (use_local_sdk)
        createLocalSdkModule(b, target, optimize)
    else
        b.dependency("qcontrol", .{ .target = target, .optimize = optimize }).module("qcontrol");

    // Shared library for dynamic loading
    const plugin = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "my_plugin",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    plugin.root_module.addImport("qcontrol", qcontrol_mod);
    b.installArtifact(plugin);

    // Object file for bundling
    const plugin_obj = b.addObject(.{
        .name = "my_plugin",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .pic = true,
        }),
    });
    plugin_obj.root_module.addImport("qcontrol", qcontrol_mod);
    const install_obj = b.addInstallFile(plugin_obj.getEmittedBin(), "lib/my_plugin.o");
    b.getInstallStep().dependOn(&install_obj.step);
}

fn createLocalSdkModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const mod = b.createModule(.{
        .root_source_file = b.path("../../src/qcontrol.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(b.path("../../include"));
    return mod;
}
```

**build.zig.zon** - Package manifest:

```zon
.{
    .name = .my_plugin,
    .version = "0.1.0",
    .fingerprint = 0x0,  // Generate with: zig build --generate-fingerprint

    .dependencies = .{
        .qcontrol = .{
            .url = "git+https://github.com/qpoint-io/qcontrol-sdk-zig#main",
            .hash = "...",  // Get hash from build error
        },
    },

    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

**Makefile** - Convenience targets:

```makefile
.PHONY: build dist clean

build:
	zig build

dist:
	zig build -Doptimize=ReleaseFast

clean:
	rm -rf zig-out .zig-cache
```

### Plugin Structure

Plugins export a single `qcontrol_plugin` descriptor using `comptime`:

```zig
const qcontrol = @import("qcontrol");

comptime {
    qcontrol.exportPlugin(.{
        .name = "my-plugin",           // Required: plugin name
        .on_init = init,               // Optional: called on load
        .on_cleanup = cleanup,         // Optional: called on unload
        .on_file_open = onFileOpen,    // Optional: file callbacks
        .on_file_read = onFileRead,
        .on_file_write = onFileWrite,
        .on_file_close = onFileClose,
        .on_exec = onExec,             // Optional: exec callbacks (v1)
        .on_exec_stdin = onExecStdin,
        .on_exec_stdout = onExecStdout,
        .on_exec_stderr = onExecStderr,
        .on_exec_exit = onExecExit,
        .on_net_connect = onNetConnect,   // Optional: net callbacks (v1)
        .on_net_accept = onNetAccept,
        .on_net_tls = onNetTls,
        .on_net_domain = onNetDomain,
        .on_net_protocol = onNetProtocol,
        .on_net_send = onNetSend,
        .on_net_recv = onNetRecv,
        .on_net_close = onNetClose,
    });
}
```

All callbacks are optional - only implement what you need.

### Building

```bash
# Debug build
zig build

# Release build (recommended for production)
zig build -Doptimize=ReleaseFast

# Build object file for bundling
zig build -Doptimize=ReleaseFast
```

Output locations:
- Shared library: `zig-out/lib/libmy_plugin.so`
- Object file: `zig-out/lib/my_plugin.o`

### Using Plugins

Load plugins dynamically via `QCONTROL_PLUGINS`:

```bash
# Single plugin
QCONTROL_PLUGINS=./my_plugin.so qcontrol wrap -- ./target

# Multiple plugins (comma-separated)
QCONTROL_PLUGINS=./logger.so,./blocker.so qcontrol wrap -- ./target
```

Or with the `--plugins` flag:

```bash
qcontrol wrap --plugins ./my_plugin.so -- ./target
```

## Bundling Plugins

For distribution, bundle plugins with the agent core into a single `.so` file.

### Bundle Configuration

Create a `bundle.toml` file:

```toml
[bundle]
output = "my-plugins.so"

[[plugins]]
source = "./file-logger"    # Plugin directory (auto-builds)

[[plugins]]
source = "./access-control"

[[plugins]]
source = "./content-filter"
```

### Creating a Bundle

1. Build plugins as object files:

```bash
# Build all plugins in examples/
make -C examples dist

# Or build individual plugin
cd my-plugin && zig build -Doptimize=ReleaseFast
```

2. Create the bundle:

```bash
qcontrol bundle --config bundle.toml
```

Or manually with object files:

```bash
qcontrol bundle --plugins plugin1.o,plugin2.o -o my-bundle.so
```

### Using Bundles

```bash
# Via command line flag
qcontrol wrap --bundle my-bundle.so -- ./target

# Via environment variable
QCONTROL_BUNDLE=./my-bundle.so qcontrol wrap -- ./target
```

## API Reference

### Plugin Lifecycle

```zig
fn init() void {
    // Called after plugin is loaded
    // Initialize resources, open log files, etc.
}

fn cleanup() void {
    // Called before plugin is unloaded
    // Clean up resources, close files, etc.
}
```

### Logger Utility

Thread-safe file logger with reentrancy protection:

```zig
const qcontrol = @import("qcontrol");

var logger: qcontrol.Logger = .{};

fn init() void {
    logger.init();
    logger.print("[my-plugin] started", .{});
}

fn cleanup() void {
    logger.print("[my-plugin] stopped", .{});
    logger.deinit();
}

fn onFileOpen(ev: *qcontrol.file.OpenEvent) qcontrol.file.OpenResult {
    logger.print("open: {s} flags=0x{x}", .{ ev.path(), ev.flags() });
    return .pass;
}
```

The log file path is controlled by `QCONTROL_LOG_FILE` (default: `/tmp/qcontrol.log`).

## File Operations

### File Callbacks

| Callback | Signature | Phase | Purpose |
|----------|-----------|-------|---------|
| `on_file_open` | `fn(*OpenEvent) OpenResult` | After open() | Decide interception |
| `on_file_read` | `fn(?*anyopaque, *ReadEvent) Action` | After read() | Observe or block |
| `on_file_write` | `fn(?*anyopaque, *WriteEvent) Action` | Before write() | Observe or block |
| `on_file_close` | `fn(?*anyopaque, *CloseEvent) void` | After close() | Cleanup state |

The `?*anyopaque` state parameter is your custom state returned from `on_file_open`.

### File Events

**OpenEvent** - passed to `on_file_open`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `path()` | `[]const u8` | File path being opened |
| `flags()` | `i32` | Open flags (O_RDONLY, O_WRONLY, etc.) |
| `mode()` | `u32` | File mode (for O_CREAT) |
| `result()` | `i32` | Result fd on success, negative errno on failure |
| `succeeded()` | `bool` | Whether open succeeded |

**ReadEvent** - passed to `on_file_read`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `fd()` | `i32` | File descriptor |
| `count()` | `usize` | Requested byte count |
| `result()` | `isize` | Bytes read or negative errno |
| `data()` | `?[]const u8` | Data that was read (if result > 0) |

**WriteEvent** - passed to `on_file_write`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `fd()` | `i32` | File descriptor |
| `count()` | `usize` | Byte count to write |
| `result()` | `isize` | Bytes written or negative errno |
| `data()` | `[]const u8` | Data being written |

**CloseEvent** - passed to `on_file_close`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `fd()` | `i32` | File descriptor |
| `result()` | `i32` | Result (0 or negative errno) |

### File Actions

**OpenResult** - return from `on_file_open`:

| Value | Description |
|-------|-------------|
| `.pass` | No interception, continue normally |
| `.block` | Block with EACCES |
| `.{ .block_errno = N }` | Block with custom errno |
| `.{ .session = Session{...} }` | Intercept with transform config |
| `.{ .state = ptr }` | Track state only, no transforms |

**Action** - return from `on_file_read`/`on_file_write`:

| Value | Description |
|-------|-------------|
| `.pass` | Continue normally |
| `.block` | Block with EACCES |
| `.{ .block_errno = N }` | Block with custom errno |

### Sessions and Transforms

Return a `Session` from `on_file_open` to configure read/write transforms:

```zig
fn onFileOpen(ev: *qcontrol.file.OpenEvent) qcontrol.file.OpenResult {
    if (!ev.succeeded()) return .pass;

    return .{ .session = .{
        .state = myState,        // Optional: custom state pointer
        .file_read = .{          // Optional: read transform config
            .prefix = "[LOG] ",
            .suffix = "\n",
            .replace = qcontrol.file.patterns(&.{
                .{ "password", "********" },
                .{ "secret", "[REDACTED]" },
            }),
            .transform = myTransformFn,
        },
        .file_write = .{         // Optional: write transform config
            // Same fields as file_read
        },
    } };
}
```

**RwConfig fields:**

| Field | Type | Description |
|-------|------|-------------|
| `prefix` | `?[]const u8` | Static prefix to prepend |
| `suffix` | `?[]const u8` | Static suffix to append |
| `prefix_fn` | `?PrefixFn` | Dynamic prefix function |
| `suffix_fn` | `?SuffixFn` | Dynamic suffix function |
| `replace` | `?[]const Pattern` | Pattern replacements |
| `transform` | `?TransformFn` | Custom transform function |

**Transform pipeline order:** `prefix` -> `replace` -> `transform` -> `suffix`

**Custom transform function:**

```zig
fn myTransform(
    state: ?*anyopaque,
    ctx: *qcontrol.file.Ctx,
    buf: *qcontrol.file.Buffer
) qcontrol.file.Action {
    // ctx provides: fd(), path(), flags()
    // buf provides: read and modify methods

    if (buf.contains("sensitive")) {
        _ = buf.replaceAll("sensitive", "[HIDDEN]");
    }

    return .pass;  // or .block to block the operation
}
```

**Dynamic prefix/suffix functions:**

```zig
fn dynamicPrefix(state: ?*anyopaque, ctx: *qcontrol.file.Ctx) ?[]const u8 {
    if (ctx.path()) |path| {
        if (std.mem.endsWith(u8, path, ".log")) {
            return "[LOG] ";
        }
    }
    return null;  // No prefix
}
```

### Buffer API

The `Buffer` type provides methods for inspecting and modifying data:

**Read operations:**

| Method | Description |
|--------|-------------|
| `slice()` | Get read-only slice of contents |
| `len()` | Get buffer length |
| `contains(needle)` | Check if buffer contains needle |
| `startsWith(prefix)` | Check if buffer starts with prefix |
| `endsWith(suffix)` | Check if buffer ends with suffix |
| `indexOf(needle)` | Find position of needle (null if not found) |

**Write operations:**

| Method | Description |
|--------|-------------|
| `prepend(data)` | Add data to beginning |
| `append(data)` | Add data to end |
| `replace(needle, replacement)` | Replace first occurrence (returns bool) |
| `replaceAll(needle, replacement)` | Replace all occurrences (returns count) |
| `remove(needle)` | Remove first occurrence (returns bool) |
| `removeAll(needle)` | Remove all occurrences (returns count) |
| `clear()` | Clear buffer contents |
| `set(data)` | Replace entire buffer contents |
| `insertAt(pos, data)` | Insert data at position |
| `removeRange(start, end)` | Remove byte range |

### Patterns

Use `patterns()` helper for declarative string replacements:

```zig
const pats = qcontrol.file.patterns(&.{
    .{ "password", "********" },
    .{ "secret", "[REDACTED]" },
    .{ "api_key", "[HIDDEN]" },
});

return .{ .session = .{
    .file_read = .{ .replace = pats },
} };
```

Or create patterns manually:

```zig
const my_patterns = &[_]qcontrol.file.Pattern{
    .{ .needle = "foo", .replacement = "bar" },
    .{ .needle = "baz", .replacement = "qux" },
};
```

## Exec Operations

> **Note:** v1 spec - not yet implemented in agent. Plugins will compile but callbacks won't be invoked.

### Exec Callbacks

| Callback | Signature | Phase | Purpose |
|----------|-----------|-------|---------|
| `on_exec` | `fn(*Event) ExecResult` | Before exec | Decide interception |
| `on_exec_stdin` | `fn(?*anyopaque, *StdinEvent) Action` | Before stdin write | Observe or block |
| `on_exec_stdout` | `fn(?*anyopaque, *StdoutEvent) Action` | After stdout read | Observe or block |
| `on_exec_stderr` | `fn(?*anyopaque, *StderrEvent) Action` | After stderr read | Observe or block |
| `on_exec_exit` | `fn(?*anyopaque, *ExitEvent) void` | After exit | Cleanup state |

### Exec Events

**Event** - passed to `on_exec`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `path()` | `[]const u8` | Executable path |
| `argc()` | `usize` | Argument count |
| `arg(i)` | `?[:0]const u8` | Argument at index |
| `argv()` | `ArgvIterator` | Iterator over arguments |
| `envc()` | `usize` | Environment variable count |
| `env(i)` | `?[:0]const u8` | Env var at index |
| `envp()` | `EnvIterator` | Iterator over env vars |
| `cwd()` | `?[]const u8` | Working directory (if set) |

**StdinEvent** - passed to `on_exec_stdin`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `pid()` | `pid_t` | Child process ID |
| `data()` | `[]const u8` | Data being written to stdin |
| `count()` | `usize` | Byte count |

**StdoutEvent** / **StderrEvent** - passed to `on_exec_stdout`/`on_exec_stderr`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `pid()` | `pid_t` | Child process ID |
| `data()` | `?[]const u8` | Data read (if result > 0) |
| `count()` | `usize` | Requested byte count |
| `result()` | `isize` | Bytes read or negative errno |

**ExitEvent** - passed to `on_exec_exit`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `pid()` | `pid_t` | Child process ID |
| `exitCode()` | `i32` | Exit code (if normal exit) |
| `exitSignal()` | `i32` | Signal number (0 if normal) |
| `exitedNormally()` | `bool` | Whether process exited normally |

### Exec Actions

**ExecResult** - return from `on_exec`:

| Value | Description |
|-------|-------------|
| `.pass` | No interception |
| `.block` | Block with EACCES |
| `.{ .block_errno = N }` | Block with custom errno |
| `.{ .session = Session{...} }` | Intercept with config |
| `.{ .state = ptr }` | Track state only |

**Action** - return from stdin/stdout/stderr callbacks:

| Value | Description |
|-------|-------------|
| `.pass` | Continue normally |
| `.block` | Block operation |
| `.{ .block_errno = N }` | Block with custom errno |

### Exec Sessions

```zig
fn onExec(ev: *qcontrol.exec.Event) qcontrol.exec.ExecResult {
    return .{ .session = .{
        .state = myState,

        // Exec modifications
        .set_path = "/usr/bin/safe-wrapper",
        .set_argv = &[_][:0]const u8{ "wrapper", "--safe" },
        .prepend_argv = &[_][:0]const u8{ "--verbose" },
        .append_argv = &[_][:0]const u8{ "--", "extra" },
        .set_env = &[_][:0]const u8{ "SAFE_MODE=1" },
        .unset_env = &[_][:0]const u8{ "DEBUG" },
        .set_cwd = "/tmp/sandbox",

        // I/O transforms
        .stdin_config = .{ .replace = ... },
        .stdout_config = .{ .prefix = "[OUT] " },
        .stderr_config = .{ .prefix = "[ERR] " },
    } };
}
```

## Network Operations

> **Note:** v1 spec - not yet implemented in agent. Plugins will compile but callbacks won't be invoked.

### Network Callbacks

| Callback | Signature | Phase | Purpose |
|----------|-----------|-------|---------|
| `on_net_connect` | `fn(*ConnectEvent) ConnectResult` | After connect() | Decide interception |
| `on_net_accept` | `fn(*AcceptEvent) AcceptResult` | After accept() | Decide interception |
| `on_net_tls` | `fn(?*anyopaque, *TlsEvent) void` | After TLS handshake | Observe |
| `on_net_domain` | `fn(?*anyopaque, *DomainEvent) void` | Domain discovered | Observe |
| `on_net_protocol` | `fn(?*anyopaque, *ProtocolEvent) void` | Protocol detected | Observe |
| `on_net_send` | `fn(?*anyopaque, *SendEvent) Action` | Before send | Observe or block |
| `on_net_recv` | `fn(?*anyopaque, *RecvEvent) Action` | After recv | Observe or block |
| `on_net_close` | `fn(?*anyopaque, *CloseEvent) void` | After close | Cleanup state |

### Network Events

**ConnectEvent** - passed to `on_net_connect`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `fd()` | `i32` | Socket file descriptor |
| `dstAddr()` | `[]const u8` | Destination IP address |
| `dstPort()` | `u16` | Destination port |
| `srcAddr()` | `?[]const u8` | Local source address |
| `srcPort()` | `u16` | Local source port |
| `result()` | `i32` | 0 on success, negative errno |
| `succeeded()` | `bool` | Whether connect succeeded |

**AcceptEvent** - passed to `on_net_accept`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `fd()` | `i32` | Accepted socket fd |
| `listenFd()` | `i32` | Listening socket fd |
| `srcAddr()` | `[]const u8` | Remote client address |
| `srcPort()` | `u16` | Remote client port |
| `dstAddr()` | `[]const u8` | Local server address |
| `dstPort()` | `u16` | Local server port |
| `result()` | `i32` | fd on success, negative errno |
| `succeeded()` | `bool` | Whether accept succeeded |

**TlsEvent** - passed to `on_net_tls`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `fd()` | `i32` | Socket fd |
| `version()` | `[]const u8` | TLS version (e.g., "TLSv1.3") |
| `cipher()` | `?[]const u8` | Cipher suite |

**DomainEvent** - passed to `on_net_domain`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `fd()` | `i32` | Socket fd |
| `domain()` | `[]const u8` | Domain name |

**ProtocolEvent** - passed to `on_net_protocol`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `fd()` | `i32` | Socket fd |
| `protocol()` | `[]const u8` | Protocol (e.g., "http/1.1", "h2") |

**SendEvent** - passed to `on_net_send`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `fd()` | `i32` | Socket fd |
| `data()` | `[]const u8` | Data being sent |
| `count()` | `usize` | Byte count |

**RecvEvent** - passed to `on_net_recv`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `fd()` | `i32` | Socket fd |
| `data()` | `?[]const u8` | Data received (if result > 0) |
| `count()` | `usize` | Requested byte count |
| `result()` | `isize` | Bytes received or negative errno |

**CloseEvent** - passed to `on_net_close`:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `fd()` | `i32` | Socket fd |
| `result()` | `i32` | 0 on success, negative errno |

### Network Actions

**ConnectResult** / **AcceptResult** - return from connect/accept callbacks:

| Value | Description |
|-------|-------------|
| `.pass` | No interception |
| `.block` | Block with EACCES |
| `.{ .block_errno = N }` | Block with custom errno |
| `.{ .session = Session{...} }` | Intercept with config |
| `.{ .state = ptr }` | Track state only |

**Action** - return from send/recv callbacks:

| Value | Description |
|-------|-------------|
| `.pass` | Continue normally |
| `.block` | Block operation |
| `.{ .block_errno = N }` | Block with custom errno |

### Network Sessions

```zig
fn onNetConnect(ev: *qcontrol.net.ConnectEvent) qcontrol.net.ConnectResult {
    return .{ .session = .{
        .state = myState,

        // Connection modifications (connect only)
        .set_addr = "proxy.example.com",
        .set_port = 8080,

        // I/O transforms
        .send_config = .{ .replace = ... },
        .recv_config = .{ .prefix = "[RECV] " },
    } };
}
```

### Network Context

The `Ctx` type in transform functions provides connection metadata:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `fd()` | `i32` | Socket fd |
| `direction()` | `Direction` | `.outbound` or `.inbound` |
| `srcAddr()` | `?[]const u8` | Source address |
| `srcPort()` | `u16` | Source port |
| `dstAddr()` | `?[]const u8` | Destination address |
| `dstPort()` | `u16` | Destination port |
| `isTls()` | `bool` | Whether TLS is active |
| `tlsVersion()` | `?[]const u8` | TLS version |
| `domain()` | `?[]const u8` | Domain name (if discovered) |
| `protocol()` | `?[]const u8` | Protocol (if detected) |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `QCONTROL_PLUGINS` | (none) | Comma-separated paths to plugin `.so` files |
| `QCONTROL_BUNDLE` | (none) | Path to bundled plugin `.so` file |
| `QCONTROL_LOG_FILE` | `/tmp/qcontrol.log` | Log file path for Logger utility |

## License

Apache License 2.0
