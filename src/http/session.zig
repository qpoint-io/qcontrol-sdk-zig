//! HTTP context and per-exchange state wrappers.

const std = @import("std");
const ffi = @import("../ffi.zig");
const net = @import("../net/mod.zig");
const action = @import("action.zig");

/// HTTP callback context shared across one exchange.
pub const Ctx = struct {
    raw: *ffi.c.qcontrol_http_ctx_t,

    /// Get the underlying net context.
    pub fn netCtx(self: *const Ctx) net.Ctx {
        return .{ .raw = &self.raw.net };
    }

    /// Get the socket file descriptor.
    pub fn fd(self: *const Ctx) i32 {
        return self.raw.net.fd;
    }

    /// Get the runtime exchange identifier.
    pub fn exchangeId(self: *const Ctx) u64 {
        return self.raw.exchange_id;
    }

    /// Get the native HTTP/2 stream id, or 0 for HTTP/1.x.
    pub fn streamId(self: *const Ctx) u32 {
        return self.raw.stream_id;
    }

    /// Get the normalized HTTP version.
    pub fn version(self: *const Ctx) action.Version {
        return action.Version.fromC(self.raw.version);
    }
};

/// Internal wrapper that lets the SDK preserve user state and free it at close.
pub const SessionState = struct {
    user_state: ?*anyopaque,

    pub fn create(user_state: ?*anyopaque) ?*SessionState {
        const wrapped = std.heap.c_allocator.create(SessionState) catch return null;
        wrapped.* = .{ .user_state = user_state };
        return wrapped;
    }

    pub fn destroy(self: *SessionState) void {
        std.heap.c_allocator.destroy(self);
    }
};
