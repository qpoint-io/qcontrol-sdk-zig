//! Exec event types wrapping C event structs.
//!
//! These provide idiomatic Zig accessors for the raw C event data.

const std = @import("std");
const ffi = @import("../ffi.zig");

// =============================================================================
// Event - Event for on_exec
// =============================================================================

/// Event passed to on_exec callback.
/// Represents a process being spawned (execve, posix_spawn, etc.)
pub const Event = struct {
    raw: *ffi.c.qcontrol_exec_event_t,

    /// Get the executable path.
    pub fn path(self: *const Event) []const u8 {
        if (self.raw.path) |p| {
            return p[0..self.raw.path_len];
        }
        return "";
    }

    /// Get the argument count.
    pub fn argc(self: *const Event) usize {
        return self.raw.argc;
    }

    /// Get argument at index as a slice.
    pub fn arg(self: *const Event, index: usize) ?[:0]const u8 {
        if (index >= self.raw.argc) return null;
        if (self.raw.argv) |args| {
            if (args[index]) |a| {
                return std.mem.span(a);
            }
        }
        return null;
    }

    /// Get all arguments as an iterator.
    pub fn argv(self: *const Event) ArgvIterator {
        return .{
            .argv = self.raw.argv,
            .argc = self.raw.argc,
            .index = 0,
        };
    }

    /// Get environment variable count.
    pub fn envc(self: *const Event) usize {
        return self.raw.envc;
    }

    /// Get environment variable at index as a slice.
    pub fn env(self: *const Event, index: usize) ?[:0]const u8 {
        if (index >= self.raw.envc) return null;
        if (self.raw.envp) |env_vars| {
            if (env_vars[index]) |e| {
                return std.mem.span(e);
            }
        }
        return null;
    }

    /// Get all environment variables as an iterator.
    pub fn envp(self: *const Event) EnvIterator {
        return .{
            .envp = self.raw.envp,
            .envc = self.raw.envc,
            .index = 0,
        };
    }

    /// Get the working directory (may be null if not changed).
    pub fn cwd(self: *const Event) ?[]const u8 {
        if (self.raw.cwd) |c| {
            return c[0..self.raw.cwd_len];
        }
        return null;
    }
};

/// Iterator for arguments.
pub const ArgvIterator = struct {
    argv: ?[*]const ?[*:0]const u8,
    argc: usize,
    index: usize,

    pub fn next(self: *ArgvIterator) ?[:0]const u8 {
        if (self.index >= self.argc) return null;
        if (self.argv) |argv| {
            if (argv[self.index]) |a| {
                self.index += 1;
                return std.mem.span(a);
            }
        }
        self.index += 1;
        return null;
    }
};

/// Iterator for environment variables.
pub const EnvIterator = struct {
    envp: ?[*]const ?[*:0]const u8,
    envc: usize,
    index: usize,

    pub fn next(self: *EnvIterator) ?[:0]const u8 {
        if (self.index >= self.envc) return null;
        if (self.envp) |envp| {
            if (envp[self.index]) |e| {
                self.index += 1;
                return std.mem.span(e);
            }
        }
        self.index += 1;
        return null;
    }
};

// =============================================================================
// StdinEvent - Event for on_exec_stdin
// =============================================================================

/// Event passed to on_exec_stdin callback.
/// Data flowing to child process stdin.
pub const StdinEvent = struct {
    raw: *ffi.c.qcontrol_exec_stdin_event_t,

    /// Get the child process ID.
    pub fn pid(self: *const StdinEvent) std.posix.pid_t {
        return self.raw.pid;
    }

    /// Get the data being written to stdin.
    pub fn data(self: *const StdinEvent) []const u8 {
        const ptr: [*]const u8 = @ptrCast(self.raw.buf orelse return &.{});
        return ptr[0..self.raw.count];
    }

    /// Get the byte count.
    pub fn count(self: *const StdinEvent) usize {
        return self.raw.count;
    }
};

// =============================================================================
// StdoutEvent - Event for on_exec_stdout
// =============================================================================

/// Event passed to on_exec_stdout callback.
/// Data flowing from child process stdout.
pub const StdoutEvent = struct {
    raw: *ffi.c.qcontrol_exec_stdout_event_t,

    /// Get the child process ID.
    pub fn pid(self: *const StdoutEvent) std.posix.pid_t {
        return self.raw.pid;
    }

    /// Get the data read from stdout. Only valid if result > 0.
    pub fn data(self: *const StdoutEvent) ?[]const u8 {
        if (self.raw.result > 0) {
            const ptr: [*]const u8 = @ptrCast(self.raw.buf orelse return null);
            return ptr[0..@intCast(self.raw.result)];
        }
        return null;
    }

    /// Get the requested byte count.
    pub fn count(self: *const StdoutEvent) usize {
        return self.raw.count;
    }

    /// Get the result (bytes read or -errno on error).
    pub fn result(self: *const StdoutEvent) isize {
        return self.raw.result;
    }
};

// =============================================================================
// StderrEvent - Event for on_exec_stderr
// =============================================================================

/// Event passed to on_exec_stderr callback.
/// Data flowing from child process stderr.
pub const StderrEvent = struct {
    raw: *ffi.c.qcontrol_exec_stderr_event_t,

    /// Get the child process ID.
    pub fn pid(self: *const StderrEvent) std.posix.pid_t {
        return self.raw.pid;
    }

    /// Get the data read from stderr. Only valid if result > 0.
    pub fn data(self: *const StderrEvent) ?[]const u8 {
        if (self.raw.result > 0) {
            const ptr: [*]const u8 = @ptrCast(self.raw.buf orelse return null);
            return ptr[0..@intCast(self.raw.result)];
        }
        return null;
    }

    /// Get the requested byte count.
    pub fn count(self: *const StderrEvent) usize {
        return self.raw.count;
    }

    /// Get the result (bytes read or -errno on error).
    pub fn result(self: *const StderrEvent) isize {
        return self.raw.result;
    }
};

// =============================================================================
// ExitEvent - Event for on_exec_exit
// =============================================================================

/// Event passed to on_exec_exit callback.
/// Child process has exited.
pub const ExitEvent = struct {
    raw: *ffi.c.qcontrol_exec_exit_event_t,

    /// Get the child process ID.
    pub fn pid(self: *const ExitEvent) std.posix.pid_t {
        return self.raw.pid;
    }

    /// Get the exit code (only valid if exitSignal() == 0).
    pub fn exitCode(self: *const ExitEvent) i32 {
        return self.raw.exit_code;
    }

    /// Get the signal number that killed the process (0 if normal exit).
    pub fn exitSignal(self: *const ExitEvent) i32 {
        return self.raw.exit_signal;
    }

    /// Check if the process exited normally.
    pub fn exitedNormally(self: *const ExitEvent) bool {
        return self.raw.exit_signal == 0;
    }
};
