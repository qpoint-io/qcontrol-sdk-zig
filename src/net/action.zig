//! Net action types returned by callbacks.
//!
//! - ConnectResult: Can return pass, block, block_errno, session, or state
//! - AcceptResult: Can return pass, block, block_errno, session, or state
//! - Action: Can return pass, block, or block_errno (for send/recv callbacks)
//! - Direction: outbound (connect) or inbound (accept)

const std = @import("std");
const ffi = @import("../ffi.zig");
const session = @import("session.zig");

// =============================================================================
// Direction - Connection direction
// =============================================================================

/// Connection direction.
pub const Direction = enum {
    /// Outbound connection (connect)
    outbound,
    /// Inbound connection (accept)
    inbound,

    /// Convert from C enum
    pub fn fromC(c_dir: ffi.c.qcontrol_net_direction_t) Direction {
        return switch (c_dir) {
            ffi.c.QCONTROL_NET_OUTBOUND => .outbound,
            ffi.c.QCONTROL_NET_INBOUND => .inbound,
            else => .outbound,
        };
    }

    /// Convert to C enum
    pub fn toC(self: Direction) ffi.c.qcontrol_net_direction_t {
        return switch (self) {
            .outbound => ffi.c.QCONTROL_NET_OUTBOUND,
            .inbound => ffi.c.QCONTROL_NET_INBOUND,
        };
    }
};

// =============================================================================
// ConnectResult - Return type for on_net_connect
// =============================================================================

/// Result returned from on_net_connect callback.
pub const ConnectResult = union(enum) {
    /// No interception, continue normally
    pass,
    /// Block the operation with EACCES
    block,
    /// Block the operation with a specific errno
    block_errno: i32,
    /// Intercept with session config
    session: session.Session,
    /// Track state only, no transforms
    state: ?*anyopaque,

    /// Convert to C ABI struct
    pub fn toC(self: ConnectResult) ffi.c.qcontrol_net_action_t {
        return switch (self) {
            .pass => .{
                .type = ffi.c.QCONTROL_NET_ACTION_PASS,
                .unnamed_0 = undefined,
            },
            .block => .{
                .type = ffi.c.QCONTROL_NET_ACTION_BLOCK,
                .unnamed_0 = undefined,
            },
            .block_errno => |errno| .{
                .type = ffi.c.QCONTROL_NET_ACTION_BLOCK_ERRNO,
                .unnamed_0 = .{ .errno_val = errno },
            },
            .session => |sess| {
                // Session.toC() returns optional due to allocation
                // On failure, fall back to PASS
                if (sess.toC()) |c_session| {
                    return .{
                        .type = ffi.c.QCONTROL_NET_ACTION_SESSION,
                        .unnamed_0 = .{ .session = c_session },
                    };
                } else {
                    return .{
                        .type = ffi.c.QCONTROL_NET_ACTION_PASS,
                        .unnamed_0 = undefined,
                    };
                }
            },
            .state => |s| {
                var wrapped = session.Session{ .state = s };
                if (wrapped.toC()) |c_session| {
                    return .{
                        .type = ffi.c.QCONTROL_NET_ACTION_STATE,
                        .unnamed_0 = .{ .state = c_session.state },
                    };
                } else {
                    return .{
                        .type = ffi.c.QCONTROL_NET_ACTION_PASS,
                        .unnamed_0 = undefined,
                    };
                }
            },
        };
    }
};

// =============================================================================
// AcceptResult - Return type for on_net_accept
// =============================================================================

/// Result returned from on_net_accept callback.
pub const AcceptResult = union(enum) {
    /// No interception, continue normally
    pass,
    /// Block the operation with EACCES
    block,
    /// Block the operation with a specific errno
    block_errno: i32,
    /// Intercept with session config
    session: session.Session,
    /// Track state only, no transforms
    state: ?*anyopaque,

    /// Convert to C ABI struct
    pub fn toC(self: AcceptResult) ffi.c.qcontrol_net_action_t {
        return switch (self) {
            .pass => .{
                .type = ffi.c.QCONTROL_NET_ACTION_PASS,
                .unnamed_0 = undefined,
            },
            .block => .{
                .type = ffi.c.QCONTROL_NET_ACTION_BLOCK,
                .unnamed_0 = undefined,
            },
            .block_errno => |errno| .{
                .type = ffi.c.QCONTROL_NET_ACTION_BLOCK_ERRNO,
                .unnamed_0 = .{ .errno_val = errno },
            },
            .session => |sess| {
                if (sess.toC()) |c_session| {
                    return .{
                        .type = ffi.c.QCONTROL_NET_ACTION_SESSION,
                        .unnamed_0 = .{ .session = c_session },
                    };
                } else {
                    return .{
                        .type = ffi.c.QCONTROL_NET_ACTION_PASS,
                        .unnamed_0 = undefined,
                    };
                }
            },
            .state => |s| {
                var wrapped = session.Session{ .state = s };
                if (wrapped.toC()) |c_session| {
                    return .{
                        .type = ffi.c.QCONTROL_NET_ACTION_STATE,
                        .unnamed_0 = .{ .state = c_session.state },
                    };
                } else {
                    return .{
                        .type = ffi.c.QCONTROL_NET_ACTION_PASS,
                        .unnamed_0 = undefined,
                    };
                }
            },
        };
    }
};

// =============================================================================
// Action - Return type for send/recv
// =============================================================================

/// Result returned from on_net_send, on_net_recv callbacks.
pub const Action = union(enum) {
    /// Continue normally
    pass,
    /// Block the operation with EACCES
    block,
    /// Block the operation with a specific errno
    block_errno: i32,

    /// Convert to C ABI struct
    pub fn toC(self: Action) ffi.c.qcontrol_net_action_t {
        return switch (self) {
            .pass => .{
                .type = ffi.c.QCONTROL_NET_ACTION_PASS,
                .unnamed_0 = undefined,
            },
            .block => .{
                .type = ffi.c.QCONTROL_NET_ACTION_BLOCK,
                .unnamed_0 = undefined,
            },
            .block_errno => |errno| .{
                .type = ffi.c.QCONTROL_NET_ACTION_BLOCK_ERRNO,
                .unnamed_0 = .{ .errno_val = errno },
            },
        };
    }
};
