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

// ============================================================================
// Core Types
// ============================================================================

const types = @import("types.zig");
pub const FilterResult = types.FilterResult;
pub const Error = types.Error;
pub const Phase = types.Phase;

// ============================================================================
// File Operation Contexts
// ============================================================================

const file = @import("file.zig");
pub const FileOpenContext = file.FileOpenContext;
pub const FileReadContext = file.FileReadContext;
pub const FileWriteContext = file.FileWriteContext;
pub const FileCloseContext = file.FileCloseContext;

// ============================================================================
// Plugin Definition
// ============================================================================

const plugin = @import("plugin.zig");
pub const Plugin = plugin.Plugin;
pub const exportPlugin = plugin.exportPlugin;

/// Filter callback types (idiomatic Zig signatures).
pub const FileOpenFilterFn = plugin.FileOpenFilterFn;
pub const FileReadFilterFn = plugin.FileReadFilterFn;
pub const FileWriteFilterFn = plugin.FileWriteFilterFn;
pub const FileCloseFilterFn = plugin.FileCloseFilterFn;

// ============================================================================
// Manual Registration API
// ============================================================================

const register = @import("register.zig");
pub const FilterHandle = register.FilterHandle;
pub const registerFileOpen = register.registerFileOpen;
pub const registerFileRead = register.registerFileRead;
pub const registerFileWrite = register.registerFileWrite;
pub const registerFileClose = register.registerFileClose;
pub const unregister = register.unregister;

// ============================================================================
// Logging
// ============================================================================

/// Scoped logger for qcontrol plugins.
pub const log = std.log.scoped(.qcontrol);

/// Thread-safe file logger.
/// Reads log path from QCONTROL_LOG_FILE environment variable,
/// defaulting to /tmp/qcontrol.log.
pub const Logger = @import("logger.zig").Logger;
