//! Exec action types returned by callbacks.
//!
//! - ExecResult: Can return pass, block, block_errno, session, or state
//! - Action: Can return pass, block, or block_errno (for stdin/stdout/stderr callbacks)

const std = @import("std");
const ffi = @import("../ffi.zig");
const session = @import("session.zig");

// =============================================================================
// ExecResult - Return type for on_exec
// =============================================================================

/// Result returned from on_exec callback.
pub const ExecResult = union(enum) {
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
    pub fn toC(self: ExecResult) ffi.c.qcontrol_exec_action_t {
        return switch (self) {
            .pass => .{
                .type = ffi.c.QCONTROL_EXEC_ACTION_PASS,
                .unnamed_0 = undefined,
            },
            .block => .{
                .type = ffi.c.QCONTROL_EXEC_ACTION_BLOCK,
                .unnamed_0 = undefined,
            },
            .block_errno => |errno| .{
                .type = ffi.c.QCONTROL_EXEC_ACTION_BLOCK_ERRNO,
                .unnamed_0 = .{ .errno_val = errno },
            },
            .session => |sess| {
                // Session.toC() returns optional due to allocation
                // On failure, fall back to PASS
                if (sess.toC()) |c_session| {
                    return .{
                        .type = ffi.c.QCONTROL_EXEC_ACTION_SESSION,
                        .unnamed_0 = .{ .session = c_session },
                    };
                } else {
                    return .{
                        .type = ffi.c.QCONTROL_EXEC_ACTION_PASS,
                        .unnamed_0 = undefined,
                    };
                }
            },
            .state => |s| blk: {
                if (session.SessionState.createStateOnly(s)) |wrapped| {
                    break :blk .{
                        .type = ffi.c.QCONTROL_EXEC_ACTION_STATE,
                        .unnamed_0 = .{ .state = wrapped },
                    };
                } else {
                    break :blk .{
                        .type = ffi.c.QCONTROL_EXEC_ACTION_PASS,
                        .unnamed_0 = undefined,
                    };
                }
            },
        };
    }
};

// =============================================================================
// Action - Return type for stdin/stdout/stderr
// =============================================================================

/// Result returned from on_exec_stdin, on_exec_stdout, on_exec_stderr callbacks.
pub const Action = union(enum) {
    /// Continue normally
    pass,
    /// Block the operation with EACCES
    block,
    /// Block the operation with a specific errno
    block_errno: i32,

    /// Convert to C ABI struct
    pub fn toC(self: Action) ffi.c.qcontrol_exec_action_t {
        return switch (self) {
            .pass => .{
                .type = ffi.c.QCONTROL_EXEC_ACTION_PASS,
                .unnamed_0 = undefined,
            },
            .block => .{
                .type = ffi.c.QCONTROL_EXEC_ACTION_BLOCK,
                .unnamed_0 = undefined,
            },
            .block_errno => |errno| .{
                .type = ffi.c.QCONTROL_EXEC_ACTION_BLOCK_ERRNO,
                .unnamed_0 = .{ .errno_val = errno },
            },
        };
    }
};
