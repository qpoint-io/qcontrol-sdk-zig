//! qcontrol SDK for Zig
//!
//! This module provides idiomatic Zig bindings for the qcontrol plugin SDK.
//! All C interop is handled internally - plugin authors work with native Zig types.
//!
//! ## Modules
//!
//! - `file`: File operation types (OpenEvent, ReadEvent, WriteEvent, CloseEvent)
//! - `exec`: Exec operation types (Event, StdinEvent, StdoutEvent, StderrEvent, ExitEvent)
//! - `net`: Network operation types (ConnectEvent, AcceptEvent, TlsEvent, SendEvent, RecvEvent, CloseEvent)
//! - `http`: HTTP exchange types (RequestEvent, ResponseEvent, BodyEvent, ExchangeCloseEvent)
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
//! fn onExec(ev: *qcontrol.exec.Event) qcontrol.exec.ExecResult {
//!     std.debug.print("exec: {s}\n", .{ev.path()});
//!     return .pass;
//! }
//!
//! fn onNetConnect(ev: *qcontrol.net.ConnectEvent) qcontrol.net.ConnectResult {
//!     std.debug.print("connect: {s}:{d}\n", .{ev.dstAddr(), ev.dstPort()});
//!     return .pass;
//! }
//!
//! fn onHttpRequest(ev: *qcontrol.http.RequestEvent) qcontrol.http.Action {
//!     std.debug.print("http {s} {s}\n", .{ ev.method(), ev.rawTarget() });
//!     return .pass;
//! }
//!
//! comptime {
//!     qcontrol.exportPlugin(.{
//!         .name = "my-plugin",
//!         .on_init = init,
//!         .on_cleanup = cleanup,
//!         .on_file_open = onFileOpen,
//!         .on_exec = onExec,
//!         .on_net_connect = onNetConnect,
//!         .on_http_request = onHttpRequest,
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
// Exec Operations
// ============================================================================

/// Exec operation types and utilities.
///
/// Contains:
/// - Events: Event, StdinEvent, StdoutEvent, StderrEvent, ExitEvent
/// - Results: ExecResult, Action
/// - Session: Session, RwConfig, Ctx
/// - Utilities: Buffer, Pattern, patterns()
///
/// Note: v1 spec - not yet implemented in agent
pub const exec = @import("exec/mod.zig");

// ============================================================================
// Network Operations
// ============================================================================

/// Network operation types and utilities.
///
/// Contains:
/// - Events: ConnectEvent, AcceptEvent, TlsEvent, DomainEvent, ProtocolEvent, SendEvent, RecvEvent, CloseEvent
/// - Results: ConnectResult, AcceptResult, Action, Direction
/// - Session: Session, RwConfig, Ctx
/// - Utilities: Buffer, Pattern, patterns()
///
/// Note: v1 spec - not yet implemented in agent
pub const net = @import("net/mod.zig");

// ============================================================================
// HTTP Operations
// ============================================================================

/// HTTP operation types and utilities.
///
/// Contains:
/// - Events: RequestEvent, ResponseEvent, BodyEvent, TrailersEvent,
///   MessageDoneEvent, ExchangeCloseEvent
/// - Results: Action, Version, MessageKind, CloseReason
/// - Context: Ctx
pub const http = @import("http/mod.zig");

// ============================================================================
// Logging
// ============================================================================

/// Scoped logger for qcontrol plugins.
pub const log = std.log.scoped(.qcontrol);

/// Thread-safe file logger.
/// Reads log path from QCONTROL_LOG_FILE environment variable,
/// defaulting to /tmp/qcontrol.log.
pub const Logger = @import("logger.zig").Logger;
