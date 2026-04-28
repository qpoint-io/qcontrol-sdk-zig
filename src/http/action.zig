//! HTTP action and enum types.

const ffi = @import("../ffi.zig");
const session = @import("session.zig");

/// Normalized HTTP version.
pub const Version = enum {
    unknown,
    http1_0,
    http1_1,
    http2,

    pub fn fromC(raw: ffi.c.qcontrol_http_version_t) Version {
        return switch (raw) {
            ffi.c.QCONTROL_HTTP_VERSION_1_0 => .http1_0,
            ffi.c.QCONTROL_HTTP_VERSION_1_1 => .http1_1,
            ffi.c.QCONTROL_HTTP_VERSION_2 => .http2,
            else => .unknown,
        };
    }
};

/// Body scheduling mode requested from one request or response head callback.
pub const BodyMode = enum {
    default,
    stream,
    buffer,

    pub fn fromC(raw: ffi.c.qcontrol_http_body_mode_t) BodyMode {
        return switch (raw) {
            ffi.c.QCONTROL_HTTP_BODY_MODE_STREAM => .stream,
            ffi.c.QCONTROL_HTTP_BODY_MODE_BUFFER => .buffer,
            else => .default,
        };
    }

    pub fn toC(self: BodyMode) ffi.c.qcontrol_http_body_mode_t {
        return switch (self) {
            .default => ffi.c.QCONTROL_HTTP_BODY_MODE_DEFAULT,
            .stream => ffi.c.QCONTROL_HTTP_BODY_MODE_STREAM,
            .buffer => ffi.c.QCONTROL_HTTP_BODY_MODE_BUFFER,
        };
    }
};

/// HTTP message kind within an exchange.
pub const MessageKind = enum {
    request,
    response,

    pub fn fromC(raw: ffi.c.qcontrol_http_message_kind_t) MessageKind {
        return switch (raw) {
            ffi.c.QCONTROL_HTTP_MESSAGE_RESPONSE => .response,
            else => .request,
        };
    }
};

/// Terminal exchange close reason.
pub const CloseReason = enum {
    complete,
    aborted,
    parse_error,
    connection_closed,

    pub fn fromC(raw: ffi.c.qcontrol_http_close_reason_t) CloseReason {
        return switch (raw) {
            ffi.c.QCONTROL_HTTP_CLOSE_COMPLETE => .complete,
            ffi.c.QCONTROL_HTTP_CLOSE_ABORTED => .aborted,
            ffi.c.QCONTROL_HTTP_CLOSE_PARSE_ERROR => .parse_error,
            ffi.c.QCONTROL_HTTP_CLOSE_CONNECTION_CLOSED => .connection_closed,
            else => .aborted,
        };
    }
};

/// Result returned from HTTP callbacks that support actions.
pub const Action = union(enum) {
    /// Continue normally.
    pass,
    /// Block the exchange.
    block,
    /// Track per-exchange state.
    state: ?*anyopaque,
    /// Continue normally and request one body scheduling mode.
    pass_with_body_mode: BodyMode,
    /// Track per-exchange state and request one body scheduling mode.
    state_with_body_mode: struct {
        user_state: ?*anyopaque,
        body_mode: BodyMode,
    },

    /// Request one body scheduling mode for the current message.
    pub fn withBodyMode(self: Action, body_mode: BodyMode) Action {
        return switch (self) {
            .pass => .{ .pass_with_body_mode = body_mode },
            .pass_with_body_mode => .{ .pass_with_body_mode = body_mode },
            .state => |user_state| .{
                .state_with_body_mode = .{
                    .user_state = user_state,
                    .body_mode = body_mode,
                },
            },
            .state_with_body_mode => |existing| .{
                .state_with_body_mode = .{
                    .user_state = existing.user_state,
                    .body_mode = body_mode,
                },
            },
            .block => .block,
        };
    }

    pub fn toC(self: Action) ffi.c.qcontrol_http_action_t {
        return switch (self) {
            .pass => .{
                .type = ffi.c.QCONTROL_HTTP_ACTION_PASS,
                .body_mode = ffi.c.QCONTROL_HTTP_BODY_MODE_DEFAULT,
                .unnamed_0 = undefined,
            },
            .block => .{
                .type = ffi.c.QCONTROL_HTTP_ACTION_BLOCK,
                .body_mode = ffi.c.QCONTROL_HTTP_BODY_MODE_DEFAULT,
                .unnamed_0 = undefined,
            },
            .state => |user_state| {
                const wrapped = session.SessionState.create(user_state) orelse return .{
                    .type = ffi.c.QCONTROL_HTTP_ACTION_PASS,
                    .body_mode = ffi.c.QCONTROL_HTTP_BODY_MODE_DEFAULT,
                    .unnamed_0 = undefined,
                };
                return .{
                    .type = ffi.c.QCONTROL_HTTP_ACTION_STATE,
                    .body_mode = ffi.c.QCONTROL_HTTP_BODY_MODE_DEFAULT,
                    .unnamed_0 = .{ .state = wrapped },
                };
            },
            .pass_with_body_mode => |body_mode| .{
                .type = ffi.c.QCONTROL_HTTP_ACTION_PASS,
                .body_mode = body_mode.toC(),
                .unnamed_0 = undefined,
            },
            .state_with_body_mode => |payload| {
                const wrapped = session.SessionState.create(payload.user_state) orelse return .{
                    .type = ffi.c.QCONTROL_HTTP_ACTION_PASS,
                    .body_mode = payload.body_mode.toC(),
                    .unnamed_0 = undefined,
                };
                return .{
                    .type = ffi.c.QCONTROL_HTTP_ACTION_STATE,
                    .body_mode = payload.body_mode.toC(),
                    .unnamed_0 = .{ .state = wrapped },
                };
            },
        };
    }
};

test "version fromC maps expected values" {
    try std.testing.expectEqual(Version.unknown, Version.fromC(ffi.c.QCONTROL_HTTP_VERSION_UNKNOWN));
    try std.testing.expectEqual(Version.http1_1, Version.fromC(ffi.c.QCONTROL_HTTP_VERSION_1_1));
    try std.testing.expectEqual(Version.http2, Version.fromC(ffi.c.QCONTROL_HTTP_VERSION_2));
}

test "body mode round-trips through action conversion" {
    const action_c = Action.pass.withBodyMode(.buffer).toC();
    try std.testing.expectEqual(ffi.c.QCONTROL_HTTP_ACTION_PASS, action_c.type);
    try std.testing.expectEqual(ffi.c.QCONTROL_HTTP_BODY_MODE_BUFFER, action_c.body_mode);
}

const std = @import("std");
