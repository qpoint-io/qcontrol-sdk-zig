//! Manual registration API for filter callbacks.
//!
//! For most use cases, prefer using `exportPlugin` from the plugin module.
//! This API is for advanced scenarios requiring dynamic registration.

const ffi = @import("ffi.zig");
const types = @import("types.zig");
const file = @import("file.zig");

pub const Error = types.Error;
pub const FilterResult = types.FilterResult;
pub const FileOpenContext = file.FileOpenContext;
pub const FileReadContext = file.FileReadContext;
pub const FileWriteContext = file.FileWriteContext;
pub const FileCloseContext = file.FileCloseContext;

/// Handle for a registered filter.
pub const FilterHandle = ffi.c.qcontrol_filter_handle_t;

/// Filter callback types (idiomatic Zig signatures).
pub const FileOpenFilterFn = *const fn (FileOpenContext) FilterResult;
pub const FileReadFilterFn = *const fn (FileReadContext) FilterResult;
pub const FileWriteFilterFn = *const fn (FileWriteContext) FilterResult;
pub const FileCloseFilterFn = *const fn (FileCloseContext) FilterResult;

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
    const result = ffi.qcontrol_unregister_filter(handle);
    if (result != 0) return error.InvalidArg;
}

// ============================================================================
// Internal: Registration helpers and wrappers
// ============================================================================

fn registerFileOpenFilter(
    name: []const u8,
    on_enter: ?ffi.RawFileOpenFilterFn,
    on_leave: ?ffi.RawFileOpenFilterFn,
) Error!FilterHandle {
    // Stack-allocate null-terminated copy (C API copies the name internally)
    var name_buf: [256]u8 = undefined;
    if (name.len >= name_buf.len) return error.InvalidArg;
    @memcpy(name_buf[0..name.len], name);
    name_buf[name.len] = 0;

    const handle = ffi.qcontrol_register_file_open_filter(@ptrCast(&name_buf), on_enter, on_leave, null);
    if (handle == 0) return error.RegisterFailed;
    return handle;
}

fn registerFileReadFilter(
    name: []const u8,
    on_enter: ?ffi.RawFileReadFilterFn,
    on_leave: ?ffi.RawFileReadFilterFn,
) Error!FilterHandle {
    var name_buf: [256]u8 = undefined;
    if (name.len >= name_buf.len) return error.InvalidArg;
    @memcpy(name_buf[0..name.len], name);
    name_buf[name.len] = 0;

    const handle = ffi.qcontrol_register_file_read_filter(@ptrCast(&name_buf), on_enter, on_leave, null);
    if (handle == 0) return error.RegisterFailed;
    return handle;
}

fn registerFileWriteFilter(
    name: []const u8,
    on_enter: ?ffi.RawFileWriteFilterFn,
    on_leave: ?ffi.RawFileWriteFilterFn,
) Error!FilterHandle {
    var name_buf: [256]u8 = undefined;
    if (name.len >= name_buf.len) return error.InvalidArg;
    @memcpy(name_buf[0..name.len], name);
    name_buf[name.len] = 0;

    const handle = ffi.qcontrol_register_file_write_filter(@ptrCast(&name_buf), on_enter, on_leave, null);
    if (handle == 0) return error.RegisterFailed;
    return handle;
}

fn registerFileCloseFilter(
    name: []const u8,
    on_enter: ?ffi.RawFileCloseFilterFn,
    on_leave: ?ffi.RawFileCloseFilterFn,
) Error!FilterHandle {
    var name_buf: [256]u8 = undefined;
    if (name.len >= name_buf.len) return error.InvalidArg;
    @memcpy(name_buf[0..name.len], name);
    name_buf[name.len] = 0;

    const handle = ffi.qcontrol_register_file_close_filter(@ptrCast(&name_buf), on_enter, on_leave, null);
    if (handle == 0) return error.RegisterFailed;
    return handle;
}

// Generate C-compatible wrapper for a Zig filter function
pub fn makeFileOpenWrapper(comptime f: FileOpenFilterFn) ffi.RawFileOpenFilterFn {
    return struct {
        fn wrapper(raw: *ffi.RawFileOpenCtx) callconv(.c) ffi.c.qcontrol_status_t {
            return f(FileOpenContext{ .raw = raw }).toRaw();
        }
    }.wrapper;
}

pub fn makeFileReadWrapper(comptime f: FileReadFilterFn) ffi.RawFileReadFilterFn {
    return struct {
        fn wrapper(raw: *ffi.RawFileReadCtx) callconv(.c) ffi.c.qcontrol_status_t {
            return f(FileReadContext{ .raw = raw }).toRaw();
        }
    }.wrapper;
}

pub fn makeFileWriteWrapper(comptime f: FileWriteFilterFn) ffi.RawFileWriteFilterFn {
    return struct {
        fn wrapper(raw: *ffi.RawFileWriteCtx) callconv(.c) ffi.c.qcontrol_status_t {
            return f(FileWriteContext{ .raw = raw }).toRaw();
        }
    }.wrapper;
}

pub fn makeFileCloseWrapper(comptime f: FileCloseFilterFn) ffi.RawFileCloseFilterFn {
    return struct {
        fn wrapper(raw: *ffi.RawFileCloseCtx) callconv(.c) ffi.c.qcontrol_status_t {
            return f(FileCloseContext{ .raw = raw }).toRaw();
        }
    }.wrapper;
}
