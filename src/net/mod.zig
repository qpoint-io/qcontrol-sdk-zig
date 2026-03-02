//! Network operation types and utilities.
//!
//! This module provides types for network operation callbacks:
//! - Events: ConnectEvent, AcceptEvent, TlsEvent, DomainEvent, ProtocolEvent, SendEvent, RecvEvent, CloseEvent
//! - Results: ConnectResult, AcceptResult, Action, Direction
//! - Session: Session, RwConfig, Ctx
//! - Utilities: Buffer, Pattern, patterns()

// Action types
pub const ConnectResult = @import("action.zig").ConnectResult;
pub const AcceptResult = @import("action.zig").AcceptResult;
pub const Action = @import("action.zig").Action;
pub const Direction = @import("action.zig").Direction;

// Event types
pub const ConnectEvent = @import("event.zig").ConnectEvent;
pub const AcceptEvent = @import("event.zig").AcceptEvent;
pub const TlsEvent = @import("event.zig").TlsEvent;
pub const DomainEvent = @import("event.zig").DomainEvent;
pub const ProtocolEvent = @import("event.zig").ProtocolEvent;
pub const SendEvent = @import("event.zig").SendEvent;
pub const RecvEvent = @import("event.zig").RecvEvent;
pub const CloseEvent = @import("event.zig").CloseEvent;

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
pub const NetConnectFn = *const fn (*ConnectEvent) ConnectResult;
pub const NetAcceptFn = *const fn (*AcceptEvent) AcceptResult;
pub const NetTlsFn = *const fn (?*anyopaque, *TlsEvent) void;
pub const NetDomainFn = *const fn (?*anyopaque, *DomainEvent) void;
pub const NetProtocolFn = *const fn (?*anyopaque, *ProtocolEvent) void;
pub const NetSendFn = *const fn (?*anyopaque, *SendEvent) Action;
pub const NetRecvFn = *const fn (?*anyopaque, *RecvEvent) Action;
pub const NetCloseFn = *const fn (?*anyopaque, *CloseEvent) void;
