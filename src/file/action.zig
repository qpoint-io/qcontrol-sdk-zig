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
            .state => |s| blk: {
                // Wrap state for ABI consistency with callback wrappers.
                // On allocation failure, fall back to PASS.
                if (session.SessionState.createStateOnly(s)) |wrapped| {
                    break :blk .{
                        .type = ffi.c.QCONTROL_FILE_ACTION_STATE,
                        .unnamed_0 = .{ .state = wrapped },
                    };
                } else {
                    break :blk .{
                        .type = ffi.c.QCONTROL_FILE_ACTION_PASS,
                        .unnamed_0 = undefined,
                    };
                }
            },
        };
    }
};

test "OpenResult.state wraps user state in SessionState" {
    var dummy: u8 = 42;
    const user_state: ?*anyopaque = @ptrCast(&dummy);

    const action_c = (OpenResult{ .state = user_state }).toC();
    try std.testing.expectEqual(ffi.c.QCONTROL_FILE_ACTION_STATE, action_c.type);
    try std.testing.expect(action_c.unnamed_0.state != null);

    const wrapped: *session.SessionState = @ptrCast(@alignCast(action_c.unnamed_0.state.?));
    defer wrapped.destroy();

    try std.testing.expect(wrapped.user_state != null);
    try std.testing.expectEqual(@intFromPtr(user_state.?), @intFromPtr(wrapped.user_state.?));
    try std.testing.expectEqual(@as(?*ffi.c.qcontrol_file_rw_config_t, null), wrapped.read_config);
    try std.testing.expectEqual(@as(?*ffi.c.qcontrol_file_rw_config_t, null), wrapped.write_config);
}

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
