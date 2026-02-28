//! Plugin definition and export.
//!
//! Provides the `Plugin` struct and `exportPlugin` function for declarative
//! plugin registration.

const std = @import("std");
const ffi = @import("ffi.zig");
const register = @import("register.zig");

pub const FilterResult = register.FilterResult;
pub const FileOpenContext = register.FileOpenContext;
pub const FileReadContext = register.FileReadContext;
pub const FileWriteContext = register.FileWriteContext;
pub const FileCloseContext = register.FileCloseContext;

/// Filter callback types (idiomatic Zig signatures).
pub const FileOpenFilterFn = register.FileOpenFilterFn;
pub const FileReadFilterFn = register.FileReadFilterFn;
pub const FileWriteFilterFn = register.FileWriteFilterFn;
pub const FileCloseFilterFn = register.FileCloseFilterFn;

/// Scoped logger for qcontrol plugins.
pub const log = std.log.scoped(.qcontrol);

/// Plugin configuration struct.
/// Set the callbacks you want to use; leave others as null.
pub const Plugin = struct {
    name: []const u8 = "zig_plugin",

    on_file_open_enter: ?FileOpenFilterFn = null,
    on_file_open_leave: ?FileOpenFilterFn = null,
    on_file_read_enter: ?FileReadFilterFn = null,
    on_file_read_leave: ?FileReadFilterFn = null,
    on_file_write_enter: ?FileWriteFilterFn = null,
    on_file_write_leave: ?FileWriteFilterFn = null,
    on_file_close_enter: ?FileCloseFilterFn = null,
    on_file_close_leave: ?FileCloseFilterFn = null,

    /// Called when the plugin is loaded, before filters are registered.
    on_init: ?*const fn () void = null,
    /// Called when the plugin is unloaded.
    on_cleanup: ?*const fn () void = null,
};

/// Export a plugin.
///
/// Use this in a comptime block, or use the `export` declaration helper:
///
/// ```zig
/// const qcontrol = @import("qcontrol");
///
/// fn onOpen(ctx: qcontrol.FileOpenContext) qcontrol.FilterResult {
///     return .pass;
/// }
///
/// comptime { qcontrol.exportPlugin(.{ .on_file_open_leave = onOpen }); }
/// ```
///
/// Or more concisely with the `_` export trick:
///
/// ```zig
/// const _ = qcontrol.exportPlugin(.{ .on_file_open_leave = onOpen });
/// ```
pub fn exportPlugin(comptime p: Plugin) void {
    // Generate the C-compatible init function
    const init_fn = struct {
        fn init() callconv(.c) c_int {
            // Call user init callback first
            if (p.on_init) |f| f();

            // Register open filter if any callbacks
            if (p.on_file_open_enter != null or p.on_file_open_leave != null) {
                _ = register.registerFileOpen(
                    p.name,
                    p.on_file_open_enter,
                    p.on_file_open_leave,
                ) catch |err| {
                    log.err("failed to register open filter: {}", .{err});
                    return -1;
                };
            }

            // Register read filter if any callbacks
            if (p.on_file_read_enter != null or p.on_file_read_leave != null) {
                _ = register.registerFileRead(
                    p.name,
                    p.on_file_read_enter,
                    p.on_file_read_leave,
                ) catch |err| {
                    log.err("failed to register read filter: {}", .{err});
                    return -1;
                };
            }

            // Register write filter if any callbacks
            if (p.on_file_write_enter != null or p.on_file_write_leave != null) {
                _ = register.registerFileWrite(
                    p.name,
                    p.on_file_write_enter,
                    p.on_file_write_leave,
                ) catch |err| {
                    log.err("failed to register write filter: {}", .{err});
                    return -1;
                };
            }

            // Register close filter if any callbacks
            if (p.on_file_close_enter != null or p.on_file_close_leave != null) {
                _ = register.registerFileClose(
                    p.name,
                    p.on_file_close_enter,
                    p.on_file_close_leave,
                ) catch |err| {
                    log.err("failed to register close filter: {}", .{err});
                    return -1;
                };
            }

            return 0; // Success
        }
    }.init;

    const cleanup_fn = struct {
        fn cleanup() callconv(.c) void {
            if (p.on_cleanup) |f| f();
        }
    }.cleanup;

    @export(&init_fn, .{ .name = "qcontrol_plugin_init" });
    @export(&cleanup_fn, .{ .name = "qcontrol_plugin_cleanup" });
}
