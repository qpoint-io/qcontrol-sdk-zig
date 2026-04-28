//! HTTP operation types and utilities.
//!
//! This module provides types for structured HTTP callbacks:
//! - Events: RequestEvent, ResponseEvent, BodyEvent, TrailersEvent,
//!   MessageDoneEvent, ExchangeCloseEvent
//! - Results: Action, Version, MessageKind, CloseReason
//! - Context: Ctx, SessionState
//! - Utilities: Header, HeaderList

pub const Action = @import("action.zig").Action;
pub const BodyMode = @import("action.zig").BodyMode;
pub const Version = @import("action.zig").Version;
pub const MessageKind = @import("action.zig").MessageKind;
pub const CloseReason = @import("action.zig").CloseReason;

pub const Header = @import("event.zig").Header;
pub const HeaderList = @import("event.zig").HeaderList;
pub const HeaderBlock = @import("event.zig").HeaderBlock;
pub const HeaderIterator = @import("event.zig").HeaderIterator;
pub const RequestHead = @import("event.zig").RequestHead;
pub const ResponseHead = @import("event.zig").ResponseHead;
pub const RequestEvent = @import("event.zig").RequestEvent;
pub const ResponseEvent = @import("event.zig").ResponseEvent;
pub const BodyEvent = @import("event.zig").BodyEvent;
pub const TrailersEvent = @import("event.zig").TrailersEvent;
pub const MessageDoneEvent = @import("event.zig").MessageDoneEvent;
pub const ExchangeCloseEvent = @import("event.zig").ExchangeCloseEvent;

pub const Ctx = @import("session.zig").Ctx;
pub const SessionState = @import("session.zig").SessionState;

pub const HttpRequestFn = *const fn (*RequestEvent) Action;
pub const HttpRequestBodyFn = *const fn (?*anyopaque, *BodyEvent) Action;
pub const HttpRequestTrailersFn = *const fn (?*anyopaque, *TrailersEvent) Action;
pub const HttpRequestDoneFn = *const fn (?*anyopaque, *MessageDoneEvent) void;
pub const HttpResponseFn = *const fn (?*anyopaque, *ResponseEvent) Action;
pub const HttpResponseBodyFn = *const fn (?*anyopaque, *BodyEvent) Action;
pub const HttpResponseTrailersFn = *const fn (?*anyopaque, *TrailersEvent) Action;
pub const HttpResponseDoneFn = *const fn (?*anyopaque, *MessageDoneEvent) void;
pub const HttpExchangeCloseFn = *const fn (?*anyopaque, *ExchangeCloseEvent) void;
