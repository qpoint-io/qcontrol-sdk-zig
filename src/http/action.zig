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

    pub fn toC(self: Action) ffi.c.qcontrol_http_action_t {
        return switch (self) {
            .pass => .{
                .type = ffi.c.QCONTROL_HTTP_ACTION_PASS,
                .unnamed_0 = undefined,
            },
            .block => .{
                .type = ffi.c.QCONTROL_HTTP_ACTION_BLOCK,
                .unnamed_0 = undefined,
            },
            .state => |user_state| {
                const wrapped = session.SessionState.create(user_state) orelse return .{
                    .type = ffi.c.QCONTROL_HTTP_ACTION_PASS,
                    .unnamed_0 = undefined,
                };
                return .{
                    .type = ffi.c.QCONTROL_HTTP_ACTION_STATE,
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

const std = @import("std");
