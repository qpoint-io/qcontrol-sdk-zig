//! Session configuration types for file operations.
//!
//! Defines the session returned from on_file_open to configure
//! how read/write operations should be transformed.

const std = @import("std");
const ffi = @import("../ffi.zig");
const pattern = @import("pattern.zig");
const buffer = @import("buffer.zig");
const action = @import("action.zig");

/// File context passed to transform functions.
pub const Ctx = struct {
    raw: *ffi.c.qcontrol_file_ctx_t,

    /// Get the file descriptor.
    pub fn fd(self: *const Ctx) i32 {
        return self.raw.fd;
    }

    /// Get the file path (may be null if not tracked from open).
    pub fn path(self: *const Ctx) ?[]const u8 {
        if (self.raw.path) |p| {
            return p[0..self.raw.path_len];
        }
        return null;
    }

    /// Get the original open flags.
    pub fn flags(self: *const Ctx) i32 {
        return self.raw.flags;
    }
};

/// Transform function signature.
/// Called during read/write to modify the buffer contents.
///
/// @param state Plugin-defined state (from session)
/// @param ctx File context (fd, path, flags)
/// @param buf Buffer to modify using Buffer methods
/// @return Action indicating whether to continue or block
pub const TransformFn = *const fn (state: ?*anyopaque, ctx: *Ctx, buf: *buffer.Buffer) action.Action;

/// Dynamic prefix function signature.
/// Called during read/write to generate a prefix dynamically.
///
/// @param state Plugin-defined state (from session)
/// @param ctx File context (fd, path, flags)
/// @return Prefix slice to prepend, or null for no prefix
pub const PrefixFn = *const fn (state: ?*anyopaque, ctx: *Ctx) ?[]const u8;

/// Dynamic suffix function signature.
/// Called during read/write to generate a suffix dynamically.
///
/// @param state Plugin-defined state (from session)
/// @param ctx File context (fd, path, flags)
/// @return Suffix slice to append, or null for no suffix
pub const SuffixFn = *const fn (state: ?*anyopaque, ctx: *Ctx) ?[]const u8;

/// Read/Write configuration for a file session.
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
    replace: ?[]const pattern.Pattern = null,
    /// Custom transform function for advanced buffer manipulation.
    transform: ?TransformFn = null,
};

/// Internal wrapper around user state that includes transform function pointers.
///
/// This allows per-file transform functions by storing them alongside the state.
/// The agent passes this as the opaque state pointer, and our trampolines/callbacks
/// unwrap it to get both the user state and transform functions.
pub const SessionState = struct {
    /// User-provided state (may be null if user didn't set state).
    user_state: ?*anyopaque,
    /// Read transform function (may be null).
    read_transform: ?TransformFn,
    /// Write transform function (may be null).
    write_transform: ?TransformFn,
    /// Read prefix function (may be null).
    read_prefix_fn: ?PrefixFn,
    /// Read suffix function (may be null).
    read_suffix_fn: ?SuffixFn,
    /// Write prefix function (may be null).
    write_prefix_fn: ?PrefixFn,
    /// Write suffix function (may be null).
    write_suffix_fn: ?SuffixFn,
    /// Read config (heap-allocated, owned by this struct).
    read_config: ?*ffi.c.qcontrol_file_rw_config_t,
    /// Write config (heap-allocated, owned by this struct).
    write_config: ?*ffi.c.qcontrol_file_rw_config_t,
    /// Pattern storage for read config.
    read_patterns: [32]ffi.c.qcontrol_file_pattern_t,
    /// Pattern storage for write config.
    write_patterns: [32]ffi.c.qcontrol_file_pattern_t,

    /// Free the SessionState wrapper (but NOT the user's state - they manage that).
    pub fn destroy(self: *SessionState) void {
        if (self.read_config) |cfg| {
            std.heap.c_allocator.destroy(cfg);
        }
        if (self.write_config) |cfg| {
            std.heap.c_allocator.destroy(cfg);
        }
        std.heap.c_allocator.destroy(self);
    }

    /// Create a state-only SessionState wrapper.
    ///
    /// Used for OpenResult.state so callback wrappers can consistently treat
    /// incoming pointers as SessionState regardless of whether the plugin
    /// returned .session or .state.
    pub fn createStateOnly(user_state: ?*anyopaque) ?*SessionState {
        const session_state = std.heap.c_allocator.create(SessionState) catch return null;
        session_state.* = .{
            .user_state = user_state,
            .read_transform = null,
            .write_transform = null,
            .read_prefix_fn = null,
            .read_suffix_fn = null,
            .write_prefix_fn = null,
            .write_suffix_fn = null,
            .read_config = null,
            .write_config = null,
            .read_patterns = undefined,
            .write_patterns = undefined,
        };
        return session_state;
    }
};

/// Trampoline for read transform - extracts transform fn from SessionState
fn readTransformTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_file_ctx_t,
    raw_buf: ?*ffi.c.qcontrol_buffer_t,
) callconv(.c) ffi.c.qcontrol_file_action_t {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse
        return .{ .type = ffi.c.QCONTROL_FILE_ACTION_PASS, .unnamed_0 = undefined }));

    if (session_state.read_transform) |transform| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        var buf = buffer.Buffer{ .raw = raw_buf.? };
        // Pass the user's state to the transform, not the SessionState
        const result = transform(session_state.user_state, &ctx, &buf);
        return result.toC();
    }
    return .{ .type = ffi.c.QCONTROL_FILE_ACTION_PASS, .unnamed_0 = undefined };
}

/// Trampoline for write transform - extracts transform fn from SessionState
fn writeTransformTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_file_ctx_t,
    raw_buf: ?*ffi.c.qcontrol_buffer_t,
) callconv(.c) ffi.c.qcontrol_file_action_t {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse
        return .{ .type = ffi.c.QCONTROL_FILE_ACTION_PASS, .unnamed_0 = undefined }));

    if (session_state.write_transform) |transform| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        var buf = buffer.Buffer{ .raw = raw_buf.? };
        // Pass the user's state to the transform, not the SessionState
        const result = transform(session_state.user_state, &ctx, &buf);
        return result.toC();
    }
    return .{ .type = ffi.c.QCONTROL_FILE_ACTION_PASS, .unnamed_0 = undefined };
}

/// Trampoline for read prefix - extracts prefix fn from SessionState
fn readPrefixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_file_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.read_prefix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// Trampoline for read suffix - extracts suffix fn from SessionState
fn readSuffixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_file_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.read_suffix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// Trampoline for write prefix - extracts prefix fn from SessionState
fn writePrefixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_file_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.write_prefix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// Trampoline for write suffix - extracts suffix fn from SessionState
fn writeSuffixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_file_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.write_suffix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// Session configuration for a file.
/// Returned from on_file_open to configure read/write behavior.
pub const Session = struct {
    /// Plugin-defined state.
    state: ?*anyopaque = null,
    /// Read transform config.
    file_read: ?RwConfig = null,
    /// Write transform config.
    file_write: ?RwConfig = null,

    /// Convert to C ABI struct.
    /// Allocates a SessionState wrapper to hold transform functions.
    /// Returns null on allocation failure.
    pub fn toC(self: *const Session) ?ffi.c.qcontrol_file_session_t {
        // Extract transform and prefix/suffix functions
        const read_transform = if (self.file_read) |r| r.transform else null;
        const write_transform = if (self.file_write) |w| w.transform else null;
        const read_prefix_fn = if (self.file_read) |r| r.prefix_fn else null;
        const read_suffix_fn = if (self.file_read) |r| r.suffix_fn else null;
        const write_prefix_fn = if (self.file_write) |w| w.prefix_fn else null;
        const write_suffix_fn = if (self.file_write) |w| w.suffix_fn else null;

        // Allocate SessionState wrapper
        const session_state = std.heap.c_allocator.create(SessionState) catch return null;
        session_state.* = .{
            .user_state = self.state,
            .read_transform = read_transform,
            .write_transform = write_transform,
            .read_prefix_fn = read_prefix_fn,
            .read_suffix_fn = read_suffix_fn,
            .write_prefix_fn = write_prefix_fn,
            .write_suffix_fn = write_suffix_fn,
            .read_config = null,
            .write_config = null,
            .read_patterns = undefined,
            .write_patterns = undefined,
        };

        var result: ffi.c.qcontrol_file_session_t = .{
            .state = session_state,
            .read = null,
            .write = null,
        };

        // Convert read config if present
        if (self.file_read) |r| {
            const read_cfg = std.heap.c_allocator.create(ffi.c.qcontrol_file_rw_config_t) catch {
                session_state.destroy();
                return null;
            };
            read_cfg.* = rwConfigToC(r, &session_state.read_patterns, true);
            session_state.read_config = read_cfg;
            result.read = read_cfg;
        }

        // Convert write config if present
        if (self.file_write) |w| {
            const write_cfg = std.heap.c_allocator.create(ffi.c.qcontrol_file_rw_config_t) catch {
                session_state.destroy();
                return null;
            };
            write_cfg.* = rwConfigToC(w, &session_state.write_patterns, false);
            session_state.write_config = write_cfg;
            result.write = write_cfg;
        }

        return result;
    }
};

/// Convert RwConfig to C struct
fn rwConfigToC(
    config: RwConfig,
    pattern_storage: *[32]ffi.c.qcontrol_file_pattern_t,
    is_read: bool,
) ffi.c.qcontrol_file_rw_config_t {
    // Convert patterns if present
    var patterns_ptr: [*c]const ffi.c.qcontrol_file_pattern_t = null;
    var patterns_count: usize = 0;

    if (config.replace) |pats| {
        const count = @min(pats.len, 32);
        for (pats[0..count], 0..) |p, i| {
            pattern_storage[i] = p.toC();
        }
        patterns_ptr = pattern_storage;
        patterns_count = count;
    }

    // Use appropriate trampoline based on read/write
    const transform_fn: ?*const fn (?*anyopaque, ?*ffi.c.qcontrol_file_ctx_t, ?*ffi.c.qcontrol_buffer_t) callconv(.c) ffi.c.qcontrol_file_action_t =
        if (config.transform != null)
        (if (is_read) &readTransformTrampoline else &writeTransformTrampoline)
    else
        null;

    // Use appropriate prefix/suffix trampolines based on read/write
    const prefix_fn_ptr: ?*const fn (?*anyopaque, ?*ffi.c.qcontrol_file_ctx_t, ?*usize) callconv(.c) ?[*]const u8 =
        if (config.prefix_fn != null)
        (if (is_read) &readPrefixTrampoline else &writePrefixTrampoline)
    else
        null;

    const suffix_fn_ptr: ?*const fn (?*anyopaque, ?*ffi.c.qcontrol_file_ctx_t, ?*usize) callconv(.c) ?[*]const u8 =
        if (config.suffix_fn != null)
        (if (is_read) &readSuffixTrampoline else &writeSuffixTrampoline)
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
