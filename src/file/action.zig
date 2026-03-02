//! File action types returned by callbacks.
//!
//! - OpenResult: Can return pass, block, block_errno, session, or state
//! - Action: Can return pass, block, or block_errno (for read/write/transform)

const std = @import("std");
const ffi = @import("../ffi.zig");
const session = @import("session.zig");

// =============================================================================
// OpenResult - Return type for on_file_open
// =============================================================================

/// Result returned from on_file_open callback.
pub const OpenResult = union(enum) {
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
    pub fn toC(self: OpenResult) ffi.c.qcontrol_file_action_t {
        return switch (self) {
            .pass => .{
                .type = ffi.c.QCONTROL_FILE_ACTION_PASS,
                .unnamed_0 = undefined,
            },
            .block => .{
                .type = ffi.c.QCONTROL_FILE_ACTION_BLOCK,
                .unnamed_0 = undefined,
            },
            .block_errno => |errno| .{
                .type = ffi.c.QCONTROL_FILE_ACTION_BLOCK_ERRNO,
                .unnamed_0 = .{ .errno_val = errno },
            },
            .session => |sess| {
                // Session.toC() returns optional due to allocation
                // On failure, fall back to PASS
                if (sess.toC()) |c_session| {
                    return .{
                        .type = ffi.c.QCONTROL_FILE_ACTION_SESSION,
                        .unnamed_0 = .{ .session = c_session },
                    };
                } else {
                    return .{
                        .type = ffi.c.QCONTROL_FILE_ACTION_PASS,
                        .unnamed_0 = undefined,
                    };
                }
            },
            .state => |s| .{
                .type = ffi.c.QCONTROL_FILE_ACTION_STATE,
                .unnamed_0 = .{ .state = s },
            },
        };
    }
};

// =============================================================================
// Action - Return type for read/write/transform
// =============================================================================

/// Result returned from on_file_read, on_file_write, and transform callbacks.
pub const Action = union(enum) {
    /// Continue normally
    pass,
    /// Block the operation with EACCES
    block,
    /// Block the operation with a specific errno
    block_errno: i32,

    /// Convert to C ABI struct
    pub fn toC(self: Action) ffi.c.qcontrol_file_action_t {
        return switch (self) {
            .pass => .{
                .type = ffi.c.QCONTROL_FILE_ACTION_PASS,
                .unnamed_0 = undefined,
            },
            .block => .{
                .type = ffi.c.QCONTROL_FILE_ACTION_BLOCK,
                .unnamed_0 = undefined,
            },
            .block_errno => |errno| .{
                .type = ffi.c.QCONTROL_FILE_ACTION_BLOCK_ERRNO,
                .unnamed_0 = .{ .errno_val = errno },
            },
        };
    }
};
