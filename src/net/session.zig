//! Session configuration types for network operations.
//!
//! Defines the session returned from on_net_connect/on_net_accept to configure
//! how send/recv operations should be transformed.

const std = @import("std");
const ffi = @import("../ffi.zig");
const file_buffer = @import("../file/buffer.zig");
const file_pattern = @import("../file/pattern.zig");
const action_mod = @import("action.zig");

// Re-export shared types from file module
pub const Buffer = file_buffer.Buffer;
pub const Pattern = file_pattern.Pattern;
pub const patterns = file_pattern.patterns;
pub const Direction = action_mod.Direction;

/// Net context passed to transform functions.
/// Contains all discovered information about the connection.
pub const Ctx = struct {
    raw: *ffi.c.qcontrol_net_ctx_t,

    /// Get the socket file descriptor.
    pub fn fd(self: *const Ctx) i32 {
        return self.raw.fd;
    }

    /// Get the connection direction.
    pub fn direction(self: *const Ctx) Direction {
        return Direction.fromC(self.raw.direction);
    }

    /// Get the source address (local for outbound, remote for inbound).
    pub fn srcAddr(self: *const Ctx) ?[]const u8 {
        if (self.raw.src_addr) |a| {
            if (self.raw.src_addr_len > 0) {
                return a[0..self.raw.src_addr_len];
            }
        }
        return null;
    }

    /// Get the source port.
    pub fn srcPort(self: *const Ctx) u16 {
        return self.raw.src_port;
    }

    /// Get the destination address (remote for outbound, local for inbound).
    pub fn dstAddr(self: *const Ctx) ?[]const u8 {
        if (self.raw.dst_addr) |a| {
            if (self.raw.dst_addr_len > 0) {
                return a[0..self.raw.dst_addr_len];
            }
        }
        return null;
    }

    /// Get the destination port.
    pub fn dstPort(self: *const Ctx) u16 {
        return self.raw.dst_port;
    }

    /// Check if this is a TLS connection.
    pub fn isTls(self: *const Ctx) bool {
        return self.raw.is_tls != 0;
    }

    /// Get the TLS version (may be empty).
    pub fn tlsVersion(self: *const Ctx) ?[]const u8 {
        if (self.raw.tls_version) |v| {
            if (self.raw.tls_version_len > 0) {
                return v[0..self.raw.tls_version_len];
            }
        }
        return null;
    }

    /// Get the domain name if discovered (may be null).
    pub fn domain(self: *const Ctx) ?[]const u8 {
        if (self.raw.domain) |d| {
            if (self.raw.domain_len > 0) {
                return d[0..self.raw.domain_len];
            }
        }
        return null;
    }

    /// Get the protocol if detected (may be null).
    pub fn protocol(self: *const Ctx) ?[]const u8 {
        if (self.raw.protocol) |p| {
            if (self.raw.protocol_len > 0) {
                return p[0..self.raw.protocol_len];
            }
        }
        return null;
    }
};

/// Transform function signature.
/// Called during send/recv to modify the buffer contents.
///
/// @param state Plugin-defined state (from session)
/// @param ctx Net context (fd, addresses, tls, domain, protocol)
/// @param buf Buffer to modify using Buffer methods
/// @return Action indicating whether to continue or block
pub const TransformFn = *const fn (state: ?*anyopaque, ctx: *Ctx, buf: *Buffer) action_mod.Action;

/// Dynamic prefix function signature.
/// Called during send/recv to generate a prefix dynamically.
///
/// @param state Plugin-defined state (from session)
/// @param ctx Net context (fd, addresses, tls, domain, protocol)
/// @return Prefix slice to prepend, or null for no prefix
pub const PrefixFn = *const fn (state: ?*anyopaque, ctx: *Ctx) ?[]const u8;

/// Dynamic suffix function signature.
/// Called during send/recv to generate a suffix dynamically.
///
/// @param state Plugin-defined state (from session)
/// @param ctx Net context (fd, addresses, tls, domain, protocol)
/// @return Suffix slice to append, or null for no suffix
pub const SuffixFn = *const fn (state: ?*anyopaque, ctx: *Ctx) ?[]const u8;

/// Read/Write configuration for network I/O (send/recv).
///
/// Transform order: prefix -> replace -> transform -> suffix
pub const RwConfig = struct {
    /// Static prefix to prepend.
    prefix: ?[]const u8 = null,
    /// Static suffix to append.
    suffix: ?[]const u8 = null,
    /// Dynamic prefix function (overrides static prefix if set).
    prefix_fn: ?PrefixFn = null,
    /// Dynamic suffix function (overrides static suffix if set).
    suffix_fn: ?SuffixFn = null,
    /// Pattern replacements.
    replace: ?[]const Pattern = null,
    /// Custom transform function for advanced buffer manipulation.
    transform: ?TransformFn = null,
};

/// Internal wrapper around user state that includes transform function pointers.
pub const SessionState = struct {
    /// User-provided state (may be null if user didn't set state).
    user_state: ?*anyopaque,
    /// Send transform function (may be null).
    send_transform: ?TransformFn,
    /// Recv transform function (may be null).
    recv_transform: ?TransformFn,
    /// Send prefix function (may be null).
    send_prefix_fn: ?PrefixFn,
    /// Send suffix function (may be null).
    send_suffix_fn: ?SuffixFn,
    /// Recv prefix function (may be null).
    recv_prefix_fn: ?PrefixFn,
    /// Recv suffix function (may be null).
    recv_suffix_fn: ?SuffixFn,
    /// Send config (heap-allocated, owned by this struct).
    send_config: ?*ffi.c.qcontrol_net_rw_config_t,
    /// Recv config (heap-allocated, owned by this struct).
    recv_config: ?*ffi.c.qcontrol_net_rw_config_t,
    /// Pattern storage for send config.
    send_patterns: [32]ffi.c.qcontrol_net_pattern_t,
    /// Pattern storage for recv config.
    recv_patterns: [32]ffi.c.qcontrol_net_pattern_t,

    /// Free the SessionState wrapper (but NOT the user's state - they manage that).
    pub fn destroy(self: *SessionState) void {
        if (self.send_config) |cfg| {
            std.heap.c_allocator.destroy(cfg);
        }
        if (self.recv_config) |cfg| {
            std.heap.c_allocator.destroy(cfg);
        }
        std.heap.c_allocator.destroy(self);
    }
};

/// Trampoline for send transform - extracts transform fn from SessionState
fn sendTransformTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_net_ctx_t,
    raw_buf: ?*ffi.c.qcontrol_buffer_t,
) callconv(.c) ffi.c.qcontrol_net_action_t {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse
        return .{ .type = ffi.c.QCONTROL_NET_ACTION_PASS, .unnamed_0 = undefined }));

    if (session_state.send_transform) |transform| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        var buf = Buffer{ .raw = raw_buf.? };
        const result = transform(session_state.user_state, &ctx, &buf);
        return result.toC();
    }
    return .{ .type = ffi.c.QCONTROL_NET_ACTION_PASS, .unnamed_0 = undefined };
}

/// Trampoline for recv transform - extracts transform fn from SessionState
fn recvTransformTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_net_ctx_t,
    raw_buf: ?*ffi.c.qcontrol_buffer_t,
) callconv(.c) ffi.c.qcontrol_net_action_t {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse
        return .{ .type = ffi.c.QCONTROL_NET_ACTION_PASS, .unnamed_0 = undefined }));

    if (session_state.recv_transform) |transform| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        var buf = Buffer{ .raw = raw_buf.? };
        const result = transform(session_state.user_state, &ctx, &buf);
        return result.toC();
    }
    return .{ .type = ffi.c.QCONTROL_NET_ACTION_PASS, .unnamed_0 = undefined };
}

/// Trampoline for send prefix - extracts prefix fn from SessionState
fn sendPrefixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_net_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.send_prefix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// Trampoline for send suffix - extracts suffix fn from SessionState
fn sendSuffixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_net_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.send_suffix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// Trampoline for recv prefix - extracts prefix fn from SessionState
fn recvPrefixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_net_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.recv_prefix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// Trampoline for recv suffix - extracts suffix fn from SessionState
fn recvSuffixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_net_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.recv_suffix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// I/O stream type for selecting appropriate trampolines.
const IoStream = enum { send, recv };

/// Convert RwConfig to C struct
fn rwConfigToC(
    config: RwConfig,
    pattern_storage: *[32]ffi.c.qcontrol_net_pattern_t,
    stream: IoStream,
) ffi.c.qcontrol_net_rw_config_t {
    // Convert patterns if present
    var patterns_ptr: [*c]const ffi.c.qcontrol_net_pattern_t = null;
    var patterns_count: usize = 0;

    if (config.replace) |pats| {
        const count = @min(pats.len, 32);
        for (pats[0..count], 0..) |p, i| {
            pattern_storage[i] = .{
                .needle = p.needle.ptr,
                .needle_len = p.needle.len,
                .replacement = p.replacement.ptr,
                .replacement_len = p.replacement.len,
            };
        }
        patterns_ptr = pattern_storage;
        patterns_count = count;
    }

    // Use appropriate trampolines based on stream
    const transform_fn: ?*const fn (?*anyopaque, ?*ffi.c.qcontrol_net_ctx_t, ?*ffi.c.qcontrol_buffer_t) callconv(.c) ffi.c.qcontrol_net_action_t =
        if (config.transform != null)
        switch (stream) {
            .send => &sendTransformTrampoline,
            .recv => &recvTransformTrampoline,
        }
    else
        null;

    const prefix_fn_ptr: ?*const fn (?*anyopaque, ?*ffi.c.qcontrol_net_ctx_t, ?*usize) callconv(.c) ?[*]const u8 =
        if (config.prefix_fn != null)
        switch (stream) {
            .send => &sendPrefixTrampoline,
            .recv => &recvPrefixTrampoline,
        }
    else
        null;

    const suffix_fn_ptr: ?*const fn (?*anyopaque, ?*ffi.c.qcontrol_net_ctx_t, ?*usize) callconv(.c) ?[*]const u8 =
        if (config.suffix_fn != null)
        switch (stream) {
            .send => &sendSuffixTrampoline,
            .recv => &recvSuffixTrampoline,
        }
    else
        null;

    return .{
        .prefix = if (config.prefix) |p| p.ptr else null,
        .prefix_len = if (config.prefix) |p| p.len else 0,
        .suffix = if (config.suffix) |s| s.ptr else null,
        .suffix_len = if (config.suffix) |s| s.len else 0,
        .prefix_fn = prefix_fn_ptr,
        .suffix_fn = suffix_fn_ptr,
        .replace = patterns_ptr,
        .replace_count = patterns_count,
        .transform = transform_fn,
    };
}

/// Session configuration for a network connection.
/// Returned from on_net_connect/on_net_accept to configure I/O behavior.
pub const Session = struct {
    /// Plugin-defined state.
    state: ?*anyopaque = null,

    // === MODIFICATIONS (connect only, NULL = no change) ===

    /// Replace destination address.
    set_addr: ?[:0]const u8 = null,
    /// Replace destination port (0 = no change).
    set_port: u16 = 0,

    // === I/O TRANSFORM CONFIGS ===

    /// Send transform config.
    send_config: ?RwConfig = null,
    /// Recv transform config.
    recv_config: ?RwConfig = null,

    /// Convert to C ABI struct.
    /// Allocates a SessionState wrapper to hold transform functions.
    /// Returns null on allocation failure.
    pub fn toC(self: *const Session) ?ffi.c.qcontrol_net_session_t {
        // Extract transform and prefix/suffix functions
        const send_transform = if (self.send_config) |c| c.transform else null;
        const recv_transform = if (self.recv_config) |c| c.transform else null;
        const send_prefix_fn = if (self.send_config) |c| c.prefix_fn else null;
        const send_suffix_fn = if (self.send_config) |c| c.suffix_fn else null;
        const recv_prefix_fn = if (self.recv_config) |c| c.prefix_fn else null;
        const recv_suffix_fn = if (self.recv_config) |c| c.suffix_fn else null;

        // Allocate SessionState wrapper
        const session_state = std.heap.c_allocator.create(SessionState) catch return null;
        session_state.* = .{
            .user_state = self.state,
            .send_transform = send_transform,
            .recv_transform = recv_transform,
            .send_prefix_fn = send_prefix_fn,
            .send_suffix_fn = send_suffix_fn,
            .recv_prefix_fn = recv_prefix_fn,
            .recv_suffix_fn = recv_suffix_fn,
            .send_config = null,
            .recv_config = null,
            .send_patterns = undefined,
            .recv_patterns = undefined,
        };

        var result: ffi.c.qcontrol_net_session_t = .{
            .state = session_state,
            .set_addr = if (self.set_addr) |a| a.ptr else null,
            .set_port = self.set_port,
            .send_config = null,
            .recv_config = null,
        };

        // Convert send config if present
        if (self.send_config) |cfg| {
            const send_cfg = std.heap.c_allocator.create(ffi.c.qcontrol_net_rw_config_t) catch {
                session_state.destroy();
                return null;
            };
            send_cfg.* = rwConfigToC(cfg, &session_state.send_patterns, .send);
            session_state.send_config = send_cfg;
            result.send_config = send_cfg;
        }

        // Convert recv config if present
        if (self.recv_config) |cfg| {
            const recv_cfg = std.heap.c_allocator.create(ffi.c.qcontrol_net_rw_config_t) catch {
                session_state.destroy();
                return null;
            };
            recv_cfg.* = rwConfigToC(cfg, &session_state.recv_patterns, .recv);
            session_state.recv_config = recv_cfg;
            result.recv_config = recv_cfg;
        }

        return result;
    }
};
