//! qcontrol SDK for Zig
//!
//! This module provides idiomatic Zig bindings for the qcontrol plugin SDK.
//! All C interop is handled internally - plugin authors work with native Zig types.
//!
//! Types are imported from C SDK headers (sdk/c/include/qcontrol/*.h) using @cImport
//! to ensure ABI compatibility and maintain a single source of truth.
//!
//! ## Example
//!
//! ```zig
//! const qcontrol = @import("qcontrol");
//!
//! fn onOpenLeave(ctx: qcontrol.FileOpenContext) qcontrol.FilterResult {
//!     qcontrol.log.info("open({s}) = {d}", .{ ctx.path(), ctx.result() });
//!     return .pass;
//! }
//!
//! comptime {
//!     qcontrol.exportPlugin(.{
//!         .name = "my_plugin",
//!         .on_file_open_leave = onOpenLeave,
//!     });
//! }
//! ```

const std = @import("std");

// Import C SDK types directly - C headers are the single source of truth
const c = @cImport({
    @cInclude("qcontrol/common.h");
    @cInclude("qcontrol/file.h");
});

/// Scoped logger for qcontrol plugins.
pub const log = std.log.scoped(.qcontrol);

// ============================================================================
// Public Types
// ============================================================================

/// Result of a filter callback.
pub const FilterResult = enum {
    /// Continue to the next filter in the chain
    pass,
    /// Continue but apply any modifications made
    modify,
    /// Block the operation (returns error to caller)
    block,

    fn toRaw(self: FilterResult) c.qcontrol_status_t {
        return switch (self) {
            .pass => c.QCONTROL_STATUS_CONTINUE,
            .modify => c.QCONTROL_STATUS_MODIFY,
            .block => c.QCONTROL_STATUS_BLOCK,
        };
    }
};

/// Errors from SDK operations.
pub const Error = error{
    /// An invalid argument was provided.
    InvalidArg,
    /// Memory allocation failed.
    NoMemory,
    /// The SDK is not initialized.
    NotInitialized,
    /// Filter registration failed.
    RegisterFailed,
};

/// Phase of the operation.
pub const Phase = enum {
    /// Before the operation executes
    enter,
    /// After the operation completes
    leave,
};

/// Context for open() operations.
pub const FileOpenContext = struct {
    raw: *RawFileOpenCtx,

    /// Get the operation phase.
    pub fn phase(self: FileOpenContext) Phase {
        return if (self.raw.phase == 0) .enter else .leave;
    }

    /// Get the file path being opened.
    pub fn path(self: FileOpenContext) []const u8 {
        return std.mem.span(self.raw.path);
    }

    /// Get the open flags.
    pub fn flags(self: FileOpenContext) i32 {
        return self.raw.flags;
    }

    /// Get the file mode (for O_CREAT).
    pub fn mode(self: FileOpenContext) u32 {
        return self.raw.mode;
    }

    /// Get the result fd (or negative errno). Only valid in leave phase.
    pub fn result(self: FileOpenContext) i32 {
        return self.raw.result;
    }

    /// Check if the operation succeeded.
    pub fn succeeded(self: FileOpenContext) bool {
        return self.raw.result >= 0;
    }

    /// Set a modified path. Only effective in enter phase with FilterResult.modify.
    pub fn setPath(self: FileOpenContext, new_path: []const u8) void {
        const len = @min(new_path.len, MAX_PATH - 1);
        @memcpy(self.raw.path_out[0..len], new_path[0..len]);
        self.raw.path_out[len] = 0;
    }
};

/// Context for read() operations.
pub const FileReadContext = struct {
    raw: *RawFileReadCtx,

    pub fn phase(self: FileReadContext) Phase {
        return if (self.raw.phase == 0) .enter else .leave;
    }

    /// Get the file descriptor.
    pub fn fd(self: FileReadContext) i32 {
        return self.raw.fd;
    }

    /// Get the requested byte count.
    pub fn count(self: FileReadContext) usize {
        return self.raw.count;
    }

    /// Get the result (bytes read or negative errno). Only valid in leave phase.
    pub fn result(self: FileReadContext) isize {
        return self.raw.result;
    }

    /// Get the buffer contents. Only valid in leave phase after successful read.
    pub fn buffer(self: FileReadContext) ?[]const u8 {
        if (self.raw.result > 0) {
            const ptr: [*]const u8 = @ptrCast(self.raw.buf orelse return null);
            return ptr[0..@intCast(self.raw.result)];
        }
        return null;
    }
};

/// Context for write() operations.
pub const FileWriteContext = struct {
    raw: *RawFileWriteCtx,

    pub fn phase(self: FileWriteContext) Phase {
        return if (self.raw.phase == 0) .enter else .leave;
    }

    /// Get the file descriptor.
    pub fn fd(self: FileWriteContext) i32 {
        return self.raw.fd;
    }

    /// Get the byte count.
    pub fn count(self: FileWriteContext) usize {
        return self.raw.count;
    }

    /// Get the result (bytes written or negative errno). Only valid in leave phase.
    pub fn result(self: FileWriteContext) isize {
        return self.raw.result;
    }

    /// Get the buffer being written.
    pub fn buffer(self: FileWriteContext) []const u8 {
        const ptr: [*]const u8 = @ptrCast(self.raw.buf orelse return &.{});
        return ptr[0..self.raw.count];
    }
};

/// Context for close() operations.
pub const FileCloseContext = struct {
    raw: *RawFileCloseCtx,

    pub fn phase(self: FileCloseContext) Phase {
        return if (self.raw.phase == 0) .enter else .leave;
    }

    /// Get the file descriptor.
    pub fn fd(self: FileCloseContext) i32 {
        return self.raw.fd;
    }

    /// Get the result (0 or negative errno). Only valid in leave phase.
    pub fn result(self: FileCloseContext) i32 {
        return self.raw.result;
    }
};

// ============================================================================
// Plugin Definition
// ============================================================================

/// Filter callback types (idiomatic Zig signatures).
pub const FileOpenFilterFn = *const fn (FileOpenContext) FilterResult;
pub const FileReadFilterFn = *const fn (FileReadContext) FilterResult;
pub const FileWriteFilterFn = *const fn (FileWriteContext) FilterResult;
pub const FileCloseFilterFn = *const fn (FileCloseContext) FilterResult;

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
                _ = registerFileOpenFilter(
                    p.name,
                    if (p.on_file_open_enter) |f| makeFileOpenWrapper(f) else null,
                    if (p.on_file_open_leave) |f| makeFileOpenWrapper(f) else null,
                ) catch |err| {
                    log.err("failed to register open filter: {}", .{err});
                    return -1;
                };
            }

            // Register read filter if any callbacks
            if (p.on_file_read_enter != null or p.on_file_read_leave != null) {
                _ = registerFileReadFilter(
                    p.name,
                    if (p.on_file_read_enter) |f| makeFileReadWrapper(f) else null,
                    if (p.on_file_read_leave) |f| makeFileReadWrapper(f) else null,
                ) catch |err| {
                    log.err("failed to register read filter: {}", .{err});
                    return -1;
                };
            }

            // Register write filter if any callbacks
            if (p.on_file_write_enter != null or p.on_file_write_leave != null) {
                _ = registerFileWriteFilter(
                    p.name,
                    if (p.on_file_write_enter) |f| makeFileWriteWrapper(f) else null,
                    if (p.on_file_write_leave) |f| makeFileWriteWrapper(f) else null,
                ) catch |err| {
                    log.err("failed to register write filter: {}", .{err});
                    return -1;
                };
            }

            // Register close filter if any callbacks
            if (p.on_file_close_enter != null or p.on_file_close_leave != null) {
                _ = registerFileCloseFilter(
                    p.name,
                    if (p.on_file_close_enter) |f| makeFileCloseWrapper(f) else null,
                    if (p.on_file_close_leave) |f| makeFileCloseWrapper(f) else null,
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

// ============================================================================
// Manual Registration API
// ============================================================================

/// Handle for a registered filter.
pub const FilterHandle = c.qcontrol_filter_handle_t;

/// Register an open filter manually.
pub fn registerFileOpen(
    name: []const u8,
    comptime on_enter: ?FileOpenFilterFn,
    comptime on_leave: ?FileOpenFilterFn,
) Error!FilterHandle {
    return registerFileOpenFilter(
        name,
        if (on_enter) |f| makeFileOpenWrapper(f) else null,
        if (on_leave) |f| makeFileOpenWrapper(f) else null,
    );
}

/// Register a read filter manually.
pub fn registerFileRead(
    name: []const u8,
    comptime on_enter: ?FileReadFilterFn,
    comptime on_leave: ?FileReadFilterFn,
) Error!FilterHandle {
    return registerFileReadFilter(
        name,
        if (on_enter) |f| makeFileReadWrapper(f) else null,
        if (on_leave) |f| makeFileReadWrapper(f) else null,
    );
}

/// Register a write filter manually.
pub fn registerFileWrite(
    name: []const u8,
    comptime on_enter: ?FileWriteFilterFn,
    comptime on_leave: ?FileWriteFilterFn,
) Error!FilterHandle {
    return registerFileWriteFilter(
        name,
        if (on_enter) |f| makeFileWriteWrapper(f) else null,
        if (on_leave) |f| makeFileWriteWrapper(f) else null,
    );
}

/// Register a close filter manually.
pub fn registerFileClose(
    name: []const u8,
    comptime on_enter: ?FileCloseFilterFn,
    comptime on_leave: ?FileCloseFilterFn,
) Error!FilterHandle {
    return registerFileCloseFilter(
        name,
        if (on_enter) |f| makeFileCloseWrapper(f) else null,
        if (on_leave) |f| makeFileCloseWrapper(f) else null,
    );
}

/// Unregister a previously registered filter.
pub fn unregister(handle: FilterHandle) Error!void {
    const result = qcontrol_unregister_filter(handle);
    if (result != 0) return error.InvalidArg;
}

// ============================================================================
// Internal: Raw C Types and FFI (imported from C SDK headers)
// ============================================================================

// Use constant from C headers
const MAX_PATH: usize = c.QCONTROL_MAX_PATH;

// Use C struct types directly for guaranteed ABI compatibility
const RawFileOpenCtx = c.qcontrol_file_open_ctx_t;
const RawFileReadCtx = c.qcontrol_file_read_ctx_t;
const RawFileWriteCtx = c.qcontrol_file_write_ctx_t;
const RawFileCloseCtx = c.qcontrol_file_close_ctx_t;

// Filter callback types using C status return type
const RawFileOpenFilterFn = *const fn (*RawFileOpenCtx) callconv(.c) c.qcontrol_status_t;
const RawFileReadFilterFn = *const fn (*RawFileReadCtx) callconv(.c) c.qcontrol_status_t;
const RawFileWriteFilterFn = *const fn (*RawFileWriteCtx) callconv(.c) c.qcontrol_status_t;
const RawFileCloseFilterFn = *const fn (*RawFileCloseCtx) callconv(.c) c.qcontrol_status_t;

extern fn qcontrol_register_file_open_filter(
    name: ?[*:0]const u8,
    on_enter: ?RawFileOpenFilterFn,
    on_leave: ?RawFileOpenFilterFn,
    user_data: ?*anyopaque,
) c.qcontrol_filter_handle_t;

extern fn qcontrol_register_file_read_filter(
    name: ?[*:0]const u8,
    on_enter: ?RawFileReadFilterFn,
    on_leave: ?RawFileReadFilterFn,
    user_data: ?*anyopaque,
) c.qcontrol_filter_handle_t;

extern fn qcontrol_register_file_write_filter(
    name: ?[*:0]const u8,
    on_enter: ?RawFileWriteFilterFn,
    on_leave: ?RawFileWriteFilterFn,
    user_data: ?*anyopaque,
) c.qcontrol_filter_handle_t;

extern fn qcontrol_register_file_close_filter(
    name: ?[*:0]const u8,
    on_enter: ?RawFileCloseFilterFn,
    on_leave: ?RawFileCloseFilterFn,
    user_data: ?*anyopaque,
) c.qcontrol_filter_handle_t;

extern fn qcontrol_unregister_filter(handle: c.qcontrol_filter_handle_t) c_int;

fn registerFileOpenFilter(
    name: []const u8,
    on_enter: ?RawFileOpenFilterFn,
    on_leave: ?RawFileOpenFilterFn,
) Error!FilterHandle {
    // Stack-allocate null-terminated copy (C API copies the name internally)
    var name_buf: [256]u8 = undefined;
    if (name.len >= name_buf.len) return error.InvalidArg;
    @memcpy(name_buf[0..name.len], name);
    name_buf[name.len] = 0;

    const handle = qcontrol_register_file_open_filter(@ptrCast(&name_buf), on_enter, on_leave, null);
    if (handle == 0) return error.RegisterFailed;
    return handle;
}

fn registerFileReadFilter(
    name: []const u8,
    on_enter: ?RawFileReadFilterFn,
    on_leave: ?RawFileReadFilterFn,
) Error!FilterHandle {
    var name_buf: [256]u8 = undefined;
    if (name.len >= name_buf.len) return error.InvalidArg;
    @memcpy(name_buf[0..name.len], name);
    name_buf[name.len] = 0;

    const handle = qcontrol_register_file_read_filter(@ptrCast(&name_buf), on_enter, on_leave, null);
    if (handle == 0) return error.RegisterFailed;
    return handle;
}

fn registerFileWriteFilter(
    name: []const u8,
    on_enter: ?RawFileWriteFilterFn,
    on_leave: ?RawFileWriteFilterFn,
) Error!FilterHandle {
    var name_buf: [256]u8 = undefined;
    if (name.len >= name_buf.len) return error.InvalidArg;
    @memcpy(name_buf[0..name.len], name);
    name_buf[name.len] = 0;

    const handle = qcontrol_register_file_write_filter(@ptrCast(&name_buf), on_enter, on_leave, null);
    if (handle == 0) return error.RegisterFailed;
    return handle;
}

fn registerFileCloseFilter(
    name: []const u8,
    on_enter: ?RawFileCloseFilterFn,
    on_leave: ?RawFileCloseFilterFn,
) Error!FilterHandle {
    var name_buf: [256]u8 = undefined;
    if (name.len >= name_buf.len) return error.InvalidArg;
    @memcpy(name_buf[0..name.len], name);
    name_buf[name.len] = 0;

    const handle = qcontrol_register_file_close_filter(@ptrCast(&name_buf), on_enter, on_leave, null);
    if (handle == 0) return error.RegisterFailed;
    return handle;
}

// Generate C-compatible wrapper for a Zig filter function
fn makeFileOpenWrapper(comptime f: FileOpenFilterFn) RawFileOpenFilterFn {
    return struct {
        fn wrapper(raw: *RawFileOpenCtx) callconv(.c) c.qcontrol_status_t {
            return f(FileOpenContext{ .raw = raw }).toRaw();
        }
    }.wrapper;
}

fn makeFileReadWrapper(comptime f: FileReadFilterFn) RawFileReadFilterFn {
    return struct {
        fn wrapper(raw: *RawFileReadCtx) callconv(.c) c.qcontrol_status_t {
            return f(FileReadContext{ .raw = raw }).toRaw();
        }
    }.wrapper;
}

fn makeFileWriteWrapper(comptime f: FileWriteFilterFn) RawFileWriteFilterFn {
    return struct {
        fn wrapper(raw: *RawFileWriteCtx) callconv(.c) c.qcontrol_status_t {
            return f(FileWriteContext{ .raw = raw }).toRaw();
        }
    }.wrapper;
}

fn makeFileCloseWrapper(comptime f: FileCloseFilterFn) RawFileCloseFilterFn {
    return struct {
        fn wrapper(raw: *RawFileCloseCtx) callconv(.c) c.qcontrol_status_t {
            return f(FileCloseContext{ .raw = raw }).toRaw();
        }
    }.wrapper;
}
