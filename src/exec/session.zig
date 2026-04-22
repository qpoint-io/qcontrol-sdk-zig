//! Session configuration types for exec operations.
//!
//! Defines the session returned from on_exec to configure
//! how stdin/stdout/stderr operations should be transformed.

const std = @import("std");
const ffi = @import("../ffi.zig");
const file_buffer = @import("../file/buffer.zig");
const file_pattern = @import("../file/pattern.zig");
const action = @import("action.zig");

// Re-export shared types from file module
pub const Buffer = file_buffer.Buffer;
pub const Pattern = file_pattern.Pattern;
pub const patterns = file_pattern.patterns;

/// Exec context passed to transform functions.
pub const Ctx = struct {
    raw: *ffi.c.qcontrol_exec_ctx_t,

    /// Get the child process ID.
    pub fn pid(self: *const Ctx) std.posix.pid_t {
        return self.raw.pid;
    }

    /// Get the executable path.
    pub fn path(self: *const Ctx) ?[]const u8 {
        if (self.raw.path) |p| {
            return p[0..self.raw.path_len];
        }
        return null;
    }

    /// Get the argument count.
    pub fn argc(self: *const Ctx) usize {
        return self.raw.argc;
    }

    /// Get argument at index as a slice.
    pub fn arg(self: *const Ctx, index: usize) ?[:0]const u8 {
        if (index >= self.raw.argc) return null;
        if (self.raw.argv) |argv| {
            if (argv[index]) |a| {
                return std.mem.span(a);
            }
        }
        return null;
    }
};

/// Transform function signature.
/// Called during stdin/stdout/stderr to modify the buffer contents.
///
/// @param state Plugin-defined state (from session)
/// @param ctx Exec context (pid, path, argv)
/// @param buf Buffer to modify using Buffer methods
/// @return Action indicating whether to continue or block
pub const TransformFn = *const fn (state: ?*anyopaque, ctx: *Ctx, buf: *Buffer) action.Action;

/// Dynamic prefix function signature.
/// Called during stdin/stdout/stderr to generate a prefix dynamically.
///
/// @param state Plugin-defined state (from session)
/// @param ctx Exec context (pid, path, argv)
/// @return Prefix slice to prepend, or null for no prefix
pub const PrefixFn = *const fn (state: ?*anyopaque, ctx: *Ctx) ?[]const u8;

/// Dynamic suffix function signature.
/// Called during stdin/stdout/stderr to generate a suffix dynamically.
///
/// @param state Plugin-defined state (from session)
/// @param ctx Exec context (pid, path, argv)
/// @return Suffix slice to append, or null for no suffix
pub const SuffixFn = *const fn (state: ?*anyopaque, ctx: *Ctx) ?[]const u8;

/// Read/Write configuration for exec I/O (stdin/stdout/stderr).
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
    /// Stdin transform function (may be null).
    stdin_transform: ?TransformFn,
    /// Stdout transform function (may be null).
    stdout_transform: ?TransformFn,
    /// Stderr transform function (may be null).
    stderr_transform: ?TransformFn,
    /// Stdin prefix function (may be null).
    stdin_prefix_fn: ?PrefixFn,
    /// Stdin suffix function (may be null).
    stdin_suffix_fn: ?SuffixFn,
    /// Stdout prefix function (may be null).
    stdout_prefix_fn: ?PrefixFn,
    /// Stdout suffix function (may be null).
    stdout_suffix_fn: ?SuffixFn,
    /// Stderr prefix function (may be null).
    stderr_prefix_fn: ?PrefixFn,
    /// Stderr suffix function (may be null).
    stderr_suffix_fn: ?SuffixFn,
    /// Stdin config (heap-allocated, owned by this struct).
    stdin_config: ?*ffi.c.qcontrol_exec_rw_config_t,
    /// Stdout config (heap-allocated, owned by this struct).
    stdout_config: ?*ffi.c.qcontrol_exec_rw_config_t,
    /// Stderr config (heap-allocated, owned by this struct).
    stderr_config: ?*ffi.c.qcontrol_exec_rw_config_t,
    /// Owned replacement path string for the exported exec session.
    set_path: ?[:0]u8,
    /// Owned replacement working directory string for the exported exec session.
    set_cwd: ?[:0]u8,
    /// Owned replacement argv strings for the exported exec session.
    set_argv_strings: std.ArrayListUnmanaged([:0]u8),
    /// Null-terminated replacement argv pointer array for the exported exec session.
    set_argv_ptrs: std.ArrayListUnmanaged(?[*:0]const u8),
    /// Owned prepended argv strings for the exported exec session.
    prepend_argv_strings: std.ArrayListUnmanaged([:0]u8),
    /// Null-terminated prepended argv pointer array for the exported exec session.
    prepend_argv_ptrs: std.ArrayListUnmanaged(?[*:0]const u8),
    /// Owned appended argv strings for the exported exec session.
    append_argv_strings: std.ArrayListUnmanaged([:0]u8),
    /// Null-terminated appended argv pointer array for the exported exec session.
    append_argv_ptrs: std.ArrayListUnmanaged(?[*:0]const u8),
    /// Owned replacement environment strings for the exported exec session.
    set_env_strings: std.ArrayListUnmanaged([:0]u8),
    /// Null-terminated replacement environment pointer array for the exported exec session.
    set_env_ptrs: std.ArrayListUnmanaged(?[*:0]const u8),
    /// Owned unset-environment key strings for the exported exec session.
    unset_env_strings: std.ArrayListUnmanaged([:0]u8),
    /// Null-terminated unset-environment pointer array for the exported exec session.
    unset_env_ptrs: std.ArrayListUnmanaged(?[*:0]const u8),
    /// Pattern storage for stdin config.
    stdin_patterns: [32]ffi.c.qcontrol_exec_pattern_t,
    /// Pattern storage for stdout config.
    stdout_patterns: [32]ffi.c.qcontrol_exec_pattern_t,
    /// Pattern storage for stderr config.
    stderr_patterns: [32]ffi.c.qcontrol_exec_pattern_t,

    /// Free the SessionState wrapper (but NOT the user's state - they manage that).
    pub fn destroy(self: *SessionState) void {
        if (self.stdin_config) |cfg| {
            std.heap.c_allocator.destroy(cfg);
        }
        if (self.stdout_config) |cfg| {
            std.heap.c_allocator.destroy(cfg);
        }
        if (self.stderr_config) |cfg| {
            std.heap.c_allocator.destroy(cfg);
        }
        if (self.set_path) |path| {
            std.heap.c_allocator.free(path);
        }
        if (self.set_cwd) |cwd| {
            std.heap.c_allocator.free(cwd);
        }
        freeCStringList(&self.set_argv_strings);
        self.set_argv_ptrs.deinit(std.heap.c_allocator);
        freeCStringList(&self.prepend_argv_strings);
        self.prepend_argv_ptrs.deinit(std.heap.c_allocator);
        freeCStringList(&self.append_argv_strings);
        self.append_argv_ptrs.deinit(std.heap.c_allocator);
        freeCStringList(&self.set_env_strings);
        self.set_env_ptrs.deinit(std.heap.c_allocator);
        freeCStringList(&self.unset_env_strings);
        self.unset_env_ptrs.deinit(std.heap.c_allocator);
        std.heap.c_allocator.destroy(self);
    }

    /// Create a state-only SessionState wrapper.
    ///
    /// This keeps the callback-side state ABI consistent even when a plugin
    /// returns `.state` instead of a full `.session`.
    pub fn createStateOnly(user_state: ?*anyopaque) ?*SessionState {
        const session_state = std.heap.c_allocator.create(SessionState) catch return null;
        session_state.* = .{
            .user_state = user_state,
            .stdin_transform = null,
            .stdout_transform = null,
            .stderr_transform = null,
            .stdin_prefix_fn = null,
            .stdin_suffix_fn = null,
            .stdout_prefix_fn = null,
            .stdout_suffix_fn = null,
            .stderr_prefix_fn = null,
            .stderr_suffix_fn = null,
            .stdin_config = null,
            .stdout_config = null,
            .stderr_config = null,
            .set_path = null,
            .set_cwd = null,
            .set_argv_strings = .{},
            .set_argv_ptrs = .{},
            .prepend_argv_strings = .{},
            .prepend_argv_ptrs = .{},
            .append_argv_strings = .{},
            .append_argv_ptrs = .{},
            .set_env_strings = .{},
            .set_env_ptrs = .{},
            .unset_env_strings = .{},
            .unset_env_ptrs = .{},
            .stdin_patterns = undefined,
            .stdout_patterns = undefined,
            .stderr_patterns = undefined,
        };
        return session_state;
    }
};

/// Trampoline for stdin transform - extracts transform fn from SessionState
fn stdinTransformTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_exec_ctx_t,
    raw_buf: ?*ffi.c.qcontrol_buffer_t,
) callconv(.c) ffi.c.qcontrol_exec_action_t {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse
        return .{ .type = ffi.c.QCONTROL_EXEC_ACTION_PASS, .unnamed_0 = undefined }));

    if (session_state.stdin_transform) |transform| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        var buf = Buffer{ .raw = raw_buf.? };
        const result = transform(session_state.user_state, &ctx, &buf);
        return result.toC();
    }
    return .{ .type = ffi.c.QCONTROL_EXEC_ACTION_PASS, .unnamed_0 = undefined };
}

/// Trampoline for stdout transform - extracts transform fn from SessionState
fn stdoutTransformTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_exec_ctx_t,
    raw_buf: ?*ffi.c.qcontrol_buffer_t,
) callconv(.c) ffi.c.qcontrol_exec_action_t {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse
        return .{ .type = ffi.c.QCONTROL_EXEC_ACTION_PASS, .unnamed_0 = undefined }));

    if (session_state.stdout_transform) |transform| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        var buf = Buffer{ .raw = raw_buf.? };
        const result = transform(session_state.user_state, &ctx, &buf);
        return result.toC();
    }
    return .{ .type = ffi.c.QCONTROL_EXEC_ACTION_PASS, .unnamed_0 = undefined };
}

/// Trampoline for stderr transform - extracts transform fn from SessionState
fn stderrTransformTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_exec_ctx_t,
    raw_buf: ?*ffi.c.qcontrol_buffer_t,
) callconv(.c) ffi.c.qcontrol_exec_action_t {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse
        return .{ .type = ffi.c.QCONTROL_EXEC_ACTION_PASS, .unnamed_0 = undefined }));

    if (session_state.stderr_transform) |transform| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        var buf = Buffer{ .raw = raw_buf.? };
        const result = transform(session_state.user_state, &ctx, &buf);
        return result.toC();
    }
    return .{ .type = ffi.c.QCONTROL_EXEC_ACTION_PASS, .unnamed_0 = undefined };
}

/// Trampoline for stdin prefix - extracts prefix fn from SessionState
fn stdinPrefixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_exec_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.stdin_prefix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// Trampoline for stdin suffix - extracts suffix fn from SessionState
fn stdinSuffixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_exec_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.stdin_suffix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// Trampoline for stdout prefix - extracts prefix fn from SessionState
fn stdoutPrefixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_exec_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.stdout_prefix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// Trampoline for stdout suffix - extracts suffix fn from SessionState
fn stdoutSuffixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_exec_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.stdout_suffix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// Trampoline for stderr prefix - extracts prefix fn from SessionState
fn stderrPrefixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_exec_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.stderr_prefix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// Trampoline for stderr suffix - extracts suffix fn from SessionState
fn stderrSuffixTrampoline(
    state: ?*anyopaque,
    raw_ctx: ?*ffi.c.qcontrol_exec_ctx_t,
    out_len: ?*usize,
) callconv(.c) ?[*]const u8 {
    const session_state: *SessionState = @ptrCast(@alignCast(state orelse return null));
    if (session_state.stderr_suffix_fn) |f| {
        var ctx = Ctx{ .raw = raw_ctx.? };
        if (f(session_state.user_state, &ctx)) |slice| {
            out_len.?.* = slice.len;
            return slice.ptr;
        }
    }
    return null;
}

/// I/O stream type for selecting appropriate trampolines.
const IoStream = enum { stdin, stdout, stderr };

/// Convert RwConfig to C struct
fn rwConfigToC(
    config: RwConfig,
    pattern_storage: *[32]ffi.c.qcontrol_exec_pattern_t,
    stream: IoStream,
) ffi.c.qcontrol_exec_rw_config_t {
    // Convert patterns if present
    var patterns_ptr: [*c]const ffi.c.qcontrol_exec_pattern_t = null;
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
    const transform_fn: ?*const fn (?*anyopaque, ?*ffi.c.qcontrol_exec_ctx_t, ?*ffi.c.qcontrol_buffer_t) callconv(.c) ffi.c.qcontrol_exec_action_t =
        if (config.transform != null)
            switch (stream) {
                .stdin => &stdinTransformTrampoline,
                .stdout => &stdoutTransformTrampoline,
                .stderr => &stderrTransformTrampoline,
            }
        else
            null;

    const prefix_fn_ptr: ?*const fn (?*anyopaque, ?*ffi.c.qcontrol_exec_ctx_t, ?*usize) callconv(.c) ?[*]const u8 =
        if (config.prefix_fn != null)
            switch (stream) {
                .stdin => &stdinPrefixTrampoline,
                .stdout => &stdoutPrefixTrampoline,
                .stderr => &stderrPrefixTrampoline,
            }
        else
            null;

    const suffix_fn_ptr: ?*const fn (?*anyopaque, ?*ffi.c.qcontrol_exec_ctx_t, ?*usize) callconv(.c) ?[*]const u8 =
        if (config.suffix_fn != null)
            switch (stream) {
                .stdin => &stdinSuffixTrampoline,
                .stdout => &stdoutSuffixTrampoline,
                .stderr => &stderrSuffixTrampoline,
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

/// Session configuration for an exec.
/// Returned from on_exec to configure I/O behavior and modifications.
pub const Session = struct {
    /// Plugin-defined state.
    state: ?*anyopaque = null,

    // === MODIFICATIONS (NULL = no change) ===

    /// Replace executable path.
    set_path: ?[:0]const u8 = null,
    /// Replace all arguments (null-terminated array).
    set_argv: ?[]const [:0]const u8 = null,
    /// Arguments to prepend before existing.
    prepend_argv: ?[]const [:0]const u8 = null,
    /// Arguments to append after existing.
    append_argv: ?[]const [:0]const u8 = null,
    /// Environment KEY=VALUE pairs to add/override.
    set_env: ?[]const [:0]const u8 = null,
    /// Environment keys to remove.
    unset_env: ?[]const [:0]const u8 = null,
    /// Replace working directory.
    set_cwd: ?[:0]const u8 = null,

    // === I/O TRANSFORM CONFIGS ===

    /// Stdin transform config.
    stdin_config: ?RwConfig = null,
    /// Stdout transform config.
    stdout_config: ?RwConfig = null,
    /// Stderr transform config.
    stderr_config: ?RwConfig = null,

    /// Convert to C ABI struct.
    /// Allocates a SessionState wrapper to hold transform functions.
    /// Returns null on allocation failure.
    pub fn toC(self: *const Session) ?ffi.c.qcontrol_exec_session_t {
        // Extract transform and prefix/suffix functions
        const stdin_transform = if (self.stdin_config) |c| c.transform else null;
        const stdout_transform = if (self.stdout_config) |c| c.transform else null;
        const stderr_transform = if (self.stderr_config) |c| c.transform else null;
        const stdin_prefix_fn = if (self.stdin_config) |c| c.prefix_fn else null;
        const stdin_suffix_fn = if (self.stdin_config) |c| c.suffix_fn else null;
        const stdout_prefix_fn = if (self.stdout_config) |c| c.prefix_fn else null;
        const stdout_suffix_fn = if (self.stdout_config) |c| c.suffix_fn else null;
        const stderr_prefix_fn = if (self.stderr_config) |c| c.prefix_fn else null;
        const stderr_suffix_fn = if (self.stderr_config) |c| c.suffix_fn else null;

        // Allocate SessionState wrapper
        const session_state = std.heap.c_allocator.create(SessionState) catch return null;
        errdefer session_state.destroy();
        session_state.* = .{
            .user_state = self.state,
            .stdin_transform = stdin_transform,
            .stdout_transform = stdout_transform,
            .stderr_transform = stderr_transform,
            .stdin_prefix_fn = stdin_prefix_fn,
            .stdin_suffix_fn = stdin_suffix_fn,
            .stdout_prefix_fn = stdout_prefix_fn,
            .stdout_suffix_fn = stdout_suffix_fn,
            .stderr_prefix_fn = stderr_prefix_fn,
            .stderr_suffix_fn = stderr_suffix_fn,
            .stdin_config = null,
            .stdout_config = null,
            .stderr_config = null,
            .set_path = null,
            .set_cwd = null,
            .set_argv_strings = .{},
            .set_argv_ptrs = .{},
            .prepend_argv_strings = .{},
            .prepend_argv_ptrs = .{},
            .append_argv_strings = .{},
            .append_argv_ptrs = .{},
            .set_env_strings = .{},
            .set_env_ptrs = .{},
            .unset_env_strings = .{},
            .unset_env_ptrs = .{},
            .stdin_patterns = undefined,
            .stdout_patterns = undefined,
            .stderr_patterns = undefined,
        };

        duplicateOptionalZString(self.set_path, &session_state.set_path) catch return null;
        duplicateCStringList(self.set_argv, &session_state.set_argv_strings, &session_state.set_argv_ptrs) catch return null;
        duplicateCStringList(self.prepend_argv, &session_state.prepend_argv_strings, &session_state.prepend_argv_ptrs) catch return null;
        duplicateCStringList(self.append_argv, &session_state.append_argv_strings, &session_state.append_argv_ptrs) catch return null;
        duplicateCStringList(self.set_env, &session_state.set_env_strings, &session_state.set_env_ptrs) catch return null;
        duplicateCStringList(self.unset_env, &session_state.unset_env_strings, &session_state.unset_env_ptrs) catch return null;
        duplicateOptionalZString(self.set_cwd, &session_state.set_cwd) catch return null;

        var result: ffi.c.qcontrol_exec_session_t = .{
            .state = session_state,
            .set_path = if (session_state.set_path) |p| p.ptr else null,
            .set_argv = if (session_state.set_argv_ptrs.items.len > 0) @ptrCast(session_state.set_argv_ptrs.items.ptr) else null,
            .prepend_argv = if (session_state.prepend_argv_ptrs.items.len > 0) @ptrCast(session_state.prepend_argv_ptrs.items.ptr) else null,
            .append_argv = if (session_state.append_argv_ptrs.items.len > 0) @ptrCast(session_state.append_argv_ptrs.items.ptr) else null,
            .set_env = if (session_state.set_env_ptrs.items.len > 0) @ptrCast(session_state.set_env_ptrs.items.ptr) else null,
            .unset_env = if (session_state.unset_env_ptrs.items.len > 0) @ptrCast(session_state.unset_env_ptrs.items.ptr) else null,
            .set_cwd = if (session_state.set_cwd) |c| c.ptr else null,
            .stdin_config = null,
            .stdout_config = null,
            .stderr_config = null,
        };

        // Convert stdin config if present
        if (self.stdin_config) |cfg| {
            const stdin_cfg = std.heap.c_allocator.create(ffi.c.qcontrol_exec_rw_config_t) catch {
                session_state.destroy();
                return null;
            };
            stdin_cfg.* = rwConfigToC(cfg, &session_state.stdin_patterns, .stdin);
            session_state.stdin_config = stdin_cfg;
            result.stdin_config = stdin_cfg;
        }

        // Convert stdout config if present
        if (self.stdout_config) |cfg| {
            const stdout_cfg = std.heap.c_allocator.create(ffi.c.qcontrol_exec_rw_config_t) catch {
                session_state.destroy();
                return null;
            };
            stdout_cfg.* = rwConfigToC(cfg, &session_state.stdout_patterns, .stdout);
            session_state.stdout_config = stdout_cfg;
            result.stdout_config = stdout_cfg;
        }

        // Convert stderr config if present
        if (self.stderr_config) |cfg| {
            const stderr_cfg = std.heap.c_allocator.create(ffi.c.qcontrol_exec_rw_config_t) catch {
                session_state.destroy();
                return null;
            };
            stderr_cfg.* = rwConfigToC(cfg, &session_state.stderr_patterns, .stderr);
            session_state.stderr_config = stderr_cfg;
            result.stderr_config = stderr_cfg;
        }

        return result;
    }
};

/// Duplicate one optional nul-terminated string into session-owned storage.
fn duplicateOptionalZString(
    value: ?[:0]const u8,
    target: *?[:0]u8,
) !void {
    if (value) |slice| {
        target.* = try std.heap.c_allocator.dupeZ(u8, slice);
    }
}

/// Duplicate one Zig string slice list into a null-terminated C pointer array
/// backed by session-owned storage.
fn duplicateCStringList(
    values: ?[]const [:0]const u8,
    strings: *std.ArrayListUnmanaged([:0]u8),
    ptrs: *std.ArrayListUnmanaged(?[*:0]const u8),
) !void {
    const list = values orelse return;

    try strings.ensureTotalCapacity(std.heap.c_allocator, list.len);
    try ptrs.ensureTotalCapacity(std.heap.c_allocator, list.len + 1);

    for (list) |entry| {
        const duplicate = try std.heap.c_allocator.dupeZ(u8, entry);
        strings.appendAssumeCapacity(duplicate);
        ptrs.appendAssumeCapacity(duplicate.ptr);
    }
    ptrs.appendAssumeCapacity(null);
}

/// Free one owned list of nul-terminated strings and reset the list state.
fn freeCStringList(list: *std.ArrayListUnmanaged([:0]u8)) void {
    for (list.items) |entry| {
        std.heap.c_allocator.free(entry);
    }
    list.deinit(std.heap.c_allocator);
}

test "Session.toC duplicates rewrite storage into owned C arrays" {
    const argv = [_][:0]const u8{
        "fixture",
        "arg",
    };
    const prepend = [_][:0]const u8{
        "pre",
    };
    const append = [_][:0]const u8{
        "post",
    };
    const env = [_][:0]const u8{
        "KEY=value",
    };
    const unset = [_][:0]const u8{
        "DROP",
    };
    const session = Session{
        .set_path = "/tmp/fixture",
        .set_argv = argv[0..],
        .prepend_argv = prepend[0..],
        .append_argv = append[0..],
        .set_env = env[0..],
        .unset_env = unset[0..],
        .set_cwd = "/var/tmp",
    };

    const c_session = session.toC() orelse return error.OutOfMemory;
    const wrapped: *SessionState = @ptrCast(@alignCast(c_session.state.?));
    defer wrapped.destroy();

    try std.testing.expect(wrapped.set_path != null);
    try std.testing.expect(wrapped.set_cwd != null);
    try std.testing.expect(c_session.set_argv != @as(?[*]const ?[*:0]const u8, @ptrCast(argv[0..].ptr)));
    try std.testing.expect(c_session.set_env != @as(?[*]const ?[*:0]const u8, @ptrCast(env[0..].ptr)));
    try std.testing.expectEqual(@as(usize, 3), wrapped.set_argv_ptrs.items.len);
    try std.testing.expectEqual(@as(usize, 2), wrapped.set_env_ptrs.items.len);
    try std.testing.expectEqualStrings("fixture", std.mem.span(c_session.set_argv.?[0].?));
    try std.testing.expectEqualStrings("arg", std.mem.span(c_session.set_argv.?[1].?));
    try std.testing.expect(c_session.set_argv.?[2] == null);
    try std.testing.expectEqualStrings("KEY=value", std.mem.span(c_session.set_env.?[0].?));
    try std.testing.expect(c_session.set_env.?[1] == null);
    try std.testing.expectEqualStrings("DROP", std.mem.span(c_session.unset_env.?[0].?));
    try std.testing.expect(c_session.unset_env.?[1] == null);
}
