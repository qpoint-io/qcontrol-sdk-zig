//! Internal FFI layer for C interop.
//!
//! This module imports C SDK headers and provides raw types and extern function
//! declarations. It is not part of the public API.

const std = @import("std");

// Import C SDK types directly - C headers are the single source of truth
pub const c = @cImport({
    @cInclude("qcontrol/common.h");
    @cInclude("qcontrol/file.h");
});

// Use constant from C headers
pub const MAX_PATH: usize = c.QCONTROL_MAX_PATH;

// Use C struct types directly for guaranteed ABI compatibility
pub const RawFileOpenCtx = c.qcontrol_file_open_ctx_t;
pub const RawFileReadCtx = c.qcontrol_file_read_ctx_t;
pub const RawFileWriteCtx = c.qcontrol_file_write_ctx_t;
pub const RawFileCloseCtx = c.qcontrol_file_close_ctx_t;

// Filter callback types using C status return type
pub const RawFileOpenFilterFn = *const fn (*RawFileOpenCtx) callconv(.c) c.qcontrol_status_t;
pub const RawFileReadFilterFn = *const fn (*RawFileReadCtx) callconv(.c) c.qcontrol_status_t;
pub const RawFileWriteFilterFn = *const fn (*RawFileWriteCtx) callconv(.c) c.qcontrol_status_t;
pub const RawFileCloseFilterFn = *const fn (*RawFileCloseCtx) callconv(.c) c.qcontrol_status_t;

// External registration functions
pub extern fn qcontrol_register_file_open_filter(
    name: ?[*:0]const u8,
    on_enter: ?RawFileOpenFilterFn,
    on_leave: ?RawFileOpenFilterFn,
    user_data: ?*anyopaque,
) c.qcontrol_filter_handle_t;

pub extern fn qcontrol_register_file_read_filter(
    name: ?[*:0]const u8,
    on_enter: ?RawFileReadFilterFn,
    on_leave: ?RawFileReadFilterFn,
    user_data: ?*anyopaque,
) c.qcontrol_filter_handle_t;

pub extern fn qcontrol_register_file_write_filter(
    name: ?[*:0]const u8,
    on_enter: ?RawFileWriteFilterFn,
    on_leave: ?RawFileWriteFilterFn,
    user_data: ?*anyopaque,
) c.qcontrol_filter_handle_t;

pub extern fn qcontrol_register_file_close_filter(
    name: ?[*:0]const u8,
    on_enter: ?RawFileCloseFilterFn,
    on_leave: ?RawFileCloseFilterFn,
    user_data: ?*anyopaque,
) c.qcontrol_filter_handle_t;

pub extern fn qcontrol_unregister_filter(handle: c.qcontrol_filter_handle_t) c_int;
