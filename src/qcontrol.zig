//! qcontrol SDK for Zig
//!
//! This module provides idiomatic Zig bindings for the qcontrol plugin SDK.
//! All C interop is handled internally - plugin authors work with native Zig types.
//!
//! ## Example
//!
//! ```zig
//! const std = @import("std");
//! const qcontrol = @import("qcontrol");
//!
//! var logger: qcontrol.Logger = .{};
//!
//! fn init() void {
//!     logger.init();
//! }
//!
//! fn cleanup() void {
//!     logger.deinit();
//! }
//!
//! fn onFileOpen(ev: *qcontrol.file.OpenEvent) qcontrol.file.OpenResult {
//!     if (std.mem.startsWith(u8, ev.path(), "/tmp/secret")) {
//!         return .block;
//!     }
//!     return .pass;
//! }
//!
//! comptime {
//!     qcontrol.exportPlugin(.{
//!         .name = "my-plugin",
//!         .on_init = init,
//!         .on_cleanup = cleanup,
//!         .on_file_open = onFileOpen,
//!     });
//! }
//! ```

const std = @import("std");

// ============================================================================
// Plugin Definition
// ============================================================================

const plugin = @import("plugin.zig");

/// Plugin configuration struct.
pub const Plugin = plugin.Plugin;

/// Export a plugin with the given configuration.
pub const exportPlugin = plugin.exportPlugin;

// ============================================================================
// File Operations
// ============================================================================

/// File operation types and utilities.
///
/// Contains:
/// - Events: OpenEvent, ReadEvent, WriteEvent, CloseEvent
/// - Results: OpenResult, Action
/// - Session: Session, RwConfig, Ctx
/// - Utilities: Buffer, Pattern, patterns()
pub const file = @import("file/mod.zig");

// ============================================================================
// Logging
// ============================================================================

/// Scoped logger for qcontrol plugins.
pub const log = std.log.scoped(.qcontrol);

/// Thread-safe file logger.
/// Reads log path from QCONTROL_LOG_FILE environment variable,
/// defaulting to /tmp/qcontrol.log.
pub const Logger = @import("logger.zig").Logger;
