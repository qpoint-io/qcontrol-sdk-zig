//! Exec operation types and utilities.
//!
//! This module provides types for exec operation callbacks:
//! - Events: Event, StdinEvent, StdoutEvent, StderrEvent, ExitEvent
//! - Results: ExecResult, Action
//! - Session: Session, RwConfig, Ctx
//! - Utilities: Buffer, Pattern, patterns()

// Action types
pub const ExecResult = @import("action.zig").ExecResult;
pub const Action = @import("action.zig").Action;

// Event types
pub const Event = @import("event.zig").Event;
pub const StdinEvent = @import("event.zig").StdinEvent;
pub const StdoutEvent = @import("event.zig").StdoutEvent;
pub const StderrEvent = @import("event.zig").StderrEvent;
pub const ExitEvent = @import("event.zig").ExitEvent;
pub const ArgvIterator = @import("event.zig").ArgvIterator;
pub const EnvIterator = @import("event.zig").EnvIterator;

// Session types
pub const Session = @import("session.zig").Session;
pub const SessionState = @import("session.zig").SessionState;
pub const RwConfig = @import("session.zig").RwConfig;
pub const Ctx = @import("session.zig").Ctx;
pub const TransformFn = @import("session.zig").TransformFn;
pub const PrefixFn = @import("session.zig").PrefixFn;
pub const SuffixFn = @import("session.zig").SuffixFn;

// Re-export Buffer and Pattern from file module (shared types)
pub const Buffer = @import("session.zig").Buffer;
pub const Pattern = @import("session.zig").Pattern;
pub const patterns = @import("session.zig").patterns;

// Callback function types
pub const ExecFn = *const fn (*Event) ExecResult;
pub const ExecStdinFn = *const fn (?*anyopaque, *StdinEvent) Action;
pub const ExecStdoutFn = *const fn (?*anyopaque, *StdoutEvent) Action;
pub const ExecStderrFn = *const fn (?*anyopaque, *StderrEvent) Action;
pub const ExecExitFn = *const fn (?*anyopaque, *ExitEvent) void;
