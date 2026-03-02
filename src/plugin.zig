//! Plugin definition and export.
//!
//! Provides the `Plugin` struct and `exportPlugin` function for declarative
//! plugin registration. Users provide idiomatic Zig callbacks; the SDK wraps
//! them with C ABI.

const std = @import("std");
const ffi = @import("ffi.zig");
const file = @import("file/mod.zig");
const exec = @import("exec/mod.zig");
const net = @import("net/mod.zig");

/// Plugin configuration struct.
/// Set the callbacks you want to use; leave others as null.
pub const Plugin = struct {
    /// Plugin name for debugging
    name: [:0]const u8 = "zig_plugin",

    // =========================================================================
    // Lifecycle callbacks (idiomatic Zig signatures)
    // =========================================================================

    /// Called after plugin is loaded.
    on_init: ?*const fn () void = null,
    /// Called before plugin is unloaded.
    on_cleanup: ?*const fn () void = null,

    // =========================================================================
    // File operation callbacks (idiomatic Zig signatures)
    // =========================================================================

    /// Called after file open completes.
    on_file_open: ?file.FileOpenFn = null,
    /// Called after file read completes.
    on_file_read: ?file.FileReadFn = null,
    /// Called before file write executes.
    on_file_write: ?file.FileWriteFn = null,
    /// Called after file close completes.
    on_file_close: ?file.FileCloseFn = null,

    // =========================================================================
    // Exec operation callbacks (v1 spec - not yet implemented in agent)
    // =========================================================================

    /// Called before exec syscall executes.
    on_exec: ?exec.ExecFn = null,
    /// Called before data is written to child stdin.
    on_exec_stdin: ?exec.ExecStdinFn = null,
    /// Called after data is read from child stdout.
    on_exec_stdout: ?exec.ExecStdoutFn = null,
    /// Called after data is read from child stderr.
    on_exec_stderr: ?exec.ExecStderrFn = null,
    /// Called when child process exits.
    on_exec_exit: ?exec.ExecExitFn = null,

    // =========================================================================
    // Network operation callbacks (v1 spec - not yet implemented in agent)
    // =========================================================================

    /// Called after connect() completes.
    on_net_connect: ?net.NetConnectFn = null,
    /// Called after accept() completes.
    on_net_accept: ?net.NetAcceptFn = null,
    /// Called when TLS handshake completes.
    on_net_tls: ?net.NetTlsFn = null,
    /// Called when domain name is discovered.
    on_net_domain: ?net.NetDomainFn = null,
    /// Called when application protocol is detected.
    on_net_protocol: ?net.NetProtocolFn = null,
    /// Called before data is sent.
    on_net_send: ?net.NetSendFn = null,
    /// Called after data is received.
    on_net_recv: ?net.NetRecvFn = null,
    /// Called when connection is closed.
    on_net_close: ?net.NetCloseFn = null,
};

/// Export a plugin.
///
/// Use this in a comptime block:
///
/// ```zig
/// const qcontrol = @import("qcontrol");
///
/// fn onOpen(ev: *qcontrol.file.OpenEvent) qcontrol.file.OpenResult {
///     return .pass;
/// }
///
/// comptime {
///     qcontrol.exportPlugin(.{
///         .name = "my-plugin",
///         .on_file_open = onOpen,
///     });
/// }
/// ```
pub fn exportPlugin(comptime p: Plugin) void {
    // Wrap init with C ABI
    const init_wrapper = if (p.on_init) |f| struct {
        fn wrapper() callconv(.c) c_int {
            f();
            return 0;
        }
    }.wrapper else null;

    // Wrap cleanup with C ABI
    const cleanup_wrapper = if (p.on_cleanup) |f| struct {
        fn wrapper() callconv(.c) void {
            f();
        }
    }.wrapper else null;

    // Wrap file open callback with C ABI
    const open_wrapper = if (p.on_file_open) |f| struct {
        fn wrapper(raw: [*c]ffi.c.qcontrol_file_open_event_t) callconv(.c) ffi.c.qcontrol_file_action_t {
            var ev = file.OpenEvent{ .raw = @ptrCast(raw) };
            return f(&ev).toC();
        }
    }.wrapper else null;

    // Wrap file read callback with C ABI
    // State is a SessionState* - extract user state from it
    const read_wrapper = if (p.on_file_read) |f| struct {
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_file_read_event_t) callconv(.c) ffi.c.qcontrol_file_action_t {
            const user_state = if (state) |s|
                @as(*file.SessionState, @ptrCast(@alignCast(s))).user_state
            else
                null;
            var ev = file.ReadEvent{ .raw = @ptrCast(raw) };
            return f(user_state, &ev).toC();
        }
    }.wrapper else null;

    // Wrap file write callback with C ABI
    // State is a SessionState* - extract user state from it
    const write_wrapper = if (p.on_file_write) |f| struct {
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_file_write_event_t) callconv(.c) ffi.c.qcontrol_file_action_t {
            const user_state = if (state) |s|
                @as(*file.SessionState, @ptrCast(@alignCast(s))).user_state
            else
                null;
            var ev = file.WriteEvent{ .raw = @ptrCast(raw) };
            return f(user_state, &ev).toC();
        }
    }.wrapper else null;

    // Wrap file close callback with C ABI
    // State is a SessionState* - extract user state, call callback, then free SessionState
    const close_wrapper = if (p.on_file_close) |f| struct {
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_file_close_event_t) callconv(.c) void {
            if (state) |s| {
                const session_state: *file.SessionState = @ptrCast(@alignCast(s));
                var ev = file.CloseEvent{ .raw = @ptrCast(raw) };
                // Call user callback with their state
                f(session_state.user_state, &ev);
                // Free the SessionState wrapper (user is responsible for their own state)
                session_state.destroy();
            } else {
                var ev = file.CloseEvent{ .raw = @ptrCast(raw) };
                f(null, &ev);
            }
        }
    }.wrapper else struct {
        // Even without a user callback, we need to free SessionState
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_file_close_event_t) callconv(.c) void {
            _ = raw;
            if (state) |s| {
                const session_state: *file.SessionState = @ptrCast(@alignCast(s));
                session_state.destroy();
            }
        }
    }.wrapper;

    // =========================================================================
    // Exec operation wrappers
    // =========================================================================

    // Wrap exec callback with C ABI
    const exec_wrapper = if (p.on_exec) |f| struct {
        fn wrapper(raw: [*c]ffi.c.qcontrol_exec_event_t) callconv(.c) ffi.c.qcontrol_exec_action_t {
            var ev = exec.Event{ .raw = @ptrCast(raw) };
            return f(&ev).toC();
        }
    }.wrapper else null;

    // Wrap exec stdin callback with C ABI
    const exec_stdin_wrapper = if (p.on_exec_stdin) |f| struct {
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_exec_stdin_event_t) callconv(.c) ffi.c.qcontrol_exec_action_t {
            const user_state = if (state) |s|
                @as(*exec.SessionState, @ptrCast(@alignCast(s))).user_state
            else
                null;
            var ev = exec.StdinEvent{ .raw = @ptrCast(raw) };
            return f(user_state, &ev).toC();
        }
    }.wrapper else null;

    // Wrap exec stdout callback with C ABI
    const exec_stdout_wrapper = if (p.on_exec_stdout) |f| struct {
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_exec_stdout_event_t) callconv(.c) ffi.c.qcontrol_exec_action_t {
            const user_state = if (state) |s|
                @as(*exec.SessionState, @ptrCast(@alignCast(s))).user_state
            else
                null;
            var ev = exec.StdoutEvent{ .raw = @ptrCast(raw) };
            return f(user_state, &ev).toC();
        }
    }.wrapper else null;

    // Wrap exec stderr callback with C ABI
    const exec_stderr_wrapper = if (p.on_exec_stderr) |f| struct {
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_exec_stderr_event_t) callconv(.c) ffi.c.qcontrol_exec_action_t {
            const user_state = if (state) |s|
                @as(*exec.SessionState, @ptrCast(@alignCast(s))).user_state
            else
                null;
            var ev = exec.StderrEvent{ .raw = @ptrCast(raw) };
            return f(user_state, &ev).toC();
        }
    }.wrapper else null;

    // Wrap exec exit callback with C ABI
    const exec_exit_wrapper = if (p.on_exec_exit) |f| struct {
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_exec_exit_event_t) callconv(.c) void {
            if (state) |s| {
                const session_state: *exec.SessionState = @ptrCast(@alignCast(s));
                var ev = exec.ExitEvent{ .raw = @ptrCast(raw) };
                f(session_state.user_state, &ev);
                session_state.destroy();
            } else {
                var ev = exec.ExitEvent{ .raw = @ptrCast(raw) };
                f(null, &ev);
            }
        }
    }.wrapper else struct {
        // Even without a user callback, we need to free SessionState
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_exec_exit_event_t) callconv(.c) void {
            _ = raw;
            if (state) |s| {
                const session_state: *exec.SessionState = @ptrCast(@alignCast(s));
                session_state.destroy();
            }
        }
    }.wrapper;

    // =========================================================================
    // Network operation wrappers
    // =========================================================================

    // Wrap net connect callback with C ABI
    const net_connect_wrapper = if (p.on_net_connect) |f| struct {
        fn wrapper(raw: [*c]ffi.c.qcontrol_net_connect_event_t) callconv(.c) ffi.c.qcontrol_net_action_t {
            var ev = net.ConnectEvent{ .raw = @ptrCast(raw) };
            return f(&ev).toC();
        }
    }.wrapper else null;

    // Wrap net accept callback with C ABI
    const net_accept_wrapper = if (p.on_net_accept) |f| struct {
        fn wrapper(raw: [*c]ffi.c.qcontrol_net_accept_event_t) callconv(.c) ffi.c.qcontrol_net_action_t {
            var ev = net.AcceptEvent{ .raw = @ptrCast(raw) };
            return f(&ev).toC();
        }
    }.wrapper else null;

    // Wrap net tls callback with C ABI
    const net_tls_wrapper = if (p.on_net_tls) |f| struct {
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_net_tls_event_t) callconv(.c) void {
            const user_state = if (state) |s|
                @as(*net.SessionState, @ptrCast(@alignCast(s))).user_state
            else
                null;
            var ev = net.TlsEvent{ .raw = @ptrCast(raw) };
            f(user_state, &ev);
        }
    }.wrapper else null;

    // Wrap net domain callback with C ABI
    const net_domain_wrapper = if (p.on_net_domain) |f| struct {
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_net_domain_event_t) callconv(.c) void {
            const user_state = if (state) |s|
                @as(*net.SessionState, @ptrCast(@alignCast(s))).user_state
            else
                null;
            var ev = net.DomainEvent{ .raw = @ptrCast(raw) };
            f(user_state, &ev);
        }
    }.wrapper else null;

    // Wrap net protocol callback with C ABI
    const net_protocol_wrapper = if (p.on_net_protocol) |f| struct {
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_net_protocol_event_t) callconv(.c) void {
            const user_state = if (state) |s|
                @as(*net.SessionState, @ptrCast(@alignCast(s))).user_state
            else
                null;
            var ev = net.ProtocolEvent{ .raw = @ptrCast(raw) };
            f(user_state, &ev);
        }
    }.wrapper else null;

    // Wrap net send callback with C ABI
    const net_send_wrapper = if (p.on_net_send) |f| struct {
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_net_send_event_t) callconv(.c) ffi.c.qcontrol_net_action_t {
            const user_state = if (state) |s|
                @as(*net.SessionState, @ptrCast(@alignCast(s))).user_state
            else
                null;
            var ev = net.SendEvent{ .raw = @ptrCast(raw) };
            return f(user_state, &ev).toC();
        }
    }.wrapper else null;

    // Wrap net recv callback with C ABI
    const net_recv_wrapper = if (p.on_net_recv) |f| struct {
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_net_recv_event_t) callconv(.c) ffi.c.qcontrol_net_action_t {
            const user_state = if (state) |s|
                @as(*net.SessionState, @ptrCast(@alignCast(s))).user_state
            else
                null;
            var ev = net.RecvEvent{ .raw = @ptrCast(raw) };
            return f(user_state, &ev).toC();
        }
    }.wrapper else null;

    // Wrap net close callback with C ABI
    const net_close_wrapper = if (p.on_net_close) |f| struct {
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_net_close_event_t) callconv(.c) void {
            if (state) |s| {
                const session_state: *net.SessionState = @ptrCast(@alignCast(s));
                var ev = net.CloseEvent{ .raw = @ptrCast(raw) };
                f(session_state.user_state, &ev);
                session_state.destroy();
            } else {
                var ev = net.CloseEvent{ .raw = @ptrCast(raw) };
                f(null, &ev);
            }
        }
    }.wrapper else struct {
        // Even without a user callback, we need to free SessionState
        fn wrapper(state: ?*anyopaque, raw: [*c]ffi.c.qcontrol_net_close_event_t) callconv(.c) void {
            _ = raw;
            if (state) |s| {
                const session_state: *net.SessionState = @ptrCast(@alignCast(s));
                session_state.destroy();
            }
        }
    }.wrapper;

    // Create the plugin descriptor
    const descriptor = ffi.c.qcontrol_plugin_t{
        .version = ffi.c.QCONTROL_PLUGIN_VERSION,
        .name = p.name.ptr,
        .on_init = init_wrapper,
        .on_cleanup = cleanup_wrapper,
        // File operations
        .on_file_open = open_wrapper,
        .on_file_read = read_wrapper,
        .on_file_write = write_wrapper,
        .on_file_close = close_wrapper,
        // Exec operations
        .on_exec = exec_wrapper,
        .on_exec_stdin = exec_stdin_wrapper,
        .on_exec_stdout = exec_stdout_wrapper,
        .on_exec_stderr = exec_stderr_wrapper,
        .on_exec_exit = exec_exit_wrapper,
        // Network operations
        .on_net_connect = net_connect_wrapper,
        .on_net_accept = net_accept_wrapper,
        .on_net_tls = net_tls_wrapper,
        .on_net_domain = net_domain_wrapper,
        .on_net_protocol = net_protocol_wrapper,
        .on_net_send = net_send_wrapper,
        .on_net_recv = net_recv_wrapper,
        .on_net_close = net_close_wrapper,
    };

    // Export the plugin descriptor
    @export(&descriptor, .{ .name = "qcontrol_plugin" });
}
