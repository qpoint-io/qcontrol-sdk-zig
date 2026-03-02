//! File operation types and utilities.
//!
//! This module provides types for file operation callbacks:
//! - Events: OpenEvent, ReadEvent, WriteEvent, CloseEvent
//! - Results: OpenResult, Action
//! - Session: Session, RwConfig, Ctx
//! - Utilities: Buffer, Pattern, patterns()

// Action types
pub const OpenResult = @import("action.zig").OpenResult;
pub const Action = @import("action.zig").Action;

// Event types
pub const OpenEvent = @import("event.zig").OpenEvent;
pub const ReadEvent = @import("event.zig").ReadEvent;
pub const WriteEvent = @import("event.zig").WriteEvent;
pub const CloseEvent = @import("event.zig").CloseEvent;

// Session types
pub const Session = @import("session.zig").Session;
pub const SessionState = @import("session.zig").SessionState;
pub const RwConfig = @import("session.zig").RwConfig;
pub const Ctx = @import("session.zig").Ctx;
pub const TransformFn = @import("session.zig").TransformFn;

// Buffer type
pub const Buffer = @import("buffer.zig").Buffer;

// Pattern types and helpers
pub const Pattern = @import("pattern.zig").Pattern;
pub const patterns = @import("pattern.zig").patterns;

// Callback function types
pub const FileOpenFn = *const fn (*OpenEvent) OpenResult;
pub const FileReadFn = *const fn (?*anyopaque, *ReadEvent) Action;
pub const FileWriteFn = *const fn (?*anyopaque, *WriteEvent) Action;
pub const FileCloseFn = *const fn (?*anyopaque, *CloseEvent) void;
