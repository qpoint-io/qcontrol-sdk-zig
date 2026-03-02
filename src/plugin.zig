//! Plugin definition and export.
//!
//! Provides the `Plugin` struct and `exportPlugin` function for declarative
//! plugin registration. Users provide idiomatic Zig callbacks; the SDK wraps
//! them with C ABI.

const std = @import("std");
const ffi = @import("ffi.zig");
const file = @import("file/mod.zig");

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

    // Create the plugin descriptor
    const descriptor = ffi.c.qcontrol_plugin_t{
        .version = ffi.c.QCONTROL_PLUGIN_VERSION,
        .name = p.name.ptr,
        .on_init = init_wrapper,
        .on_cleanup = cleanup_wrapper,
        .on_file_open = open_wrapper,
        .on_file_read = read_wrapper,
        .on_file_write = write_wrapper,
        .on_file_close = close_wrapper,
    };

    // Export the plugin descriptor
    @export(&descriptor, .{ .name = "qcontrol_plugin" });
}
