//! Thread-safe file logger for qcontrol plugins.
//!
//! Reads log path from QCONTROL_LOG_FILE environment variable,
//! defaulting to /tmp/qcontrol.log.
//!
//! Includes reentrancy protection to prevent infinite loops when
//! logging operations trigger more file operations (which would
//! trigger more logging, etc.).

const std = @import("std");

pub const Logger = struct {
    fd: std.posix.fd_t = -1,
    mutex: std.Thread.Mutex = .{},

    const default_path: [:0]const u8 = "/tmp/qcontrol.log";

    /// Thread-local reentrancy guard to prevent infinite recursion.
    threadlocal var in_logging: bool = false;

    pub fn init(self: *Logger) void {
        _ = self;
    }

    pub fn deinit(self: *Logger) void {
        if (self.fd >= 0) {
            std.posix.close(self.fd);
            self.fd = -1;
        }
    }

    pub fn print(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        // Prevent reentrancy - if we're already logging, skip to avoid infinite recursion
        if (in_logging) return;
        in_logging = true;
        defer in_logging = false;

        self.mutex.lock();
        defer self.mutex.unlock();
        self.ensureOpen();
        if (self.fd < 0) return;

        var buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, fmt ++ "\n", args) catch return;
        _ = std.posix.write(self.fd, msg) catch {};
    }

    fn ensureOpen(self: *Logger) void {
        if (self.fd >= 0) return;

        const path = self.getLogPath();
        self.fd = std.posix.open(
            path,
            .{ .ACCMODE = .WRONLY, .CREAT = true, .APPEND = true },
            0o644,
        ) catch -1;
    }

    fn getLogPath(self: *const Logger) [:0]const u8 {
        _ = self;
        const ptr = getenv("QCONTROL_LOG_FILE");
        if (ptr) |p| {
            const path = std.mem.span(p);
            if (path.len > 0) return path;
        }
        return default_path;
    }

    extern fn getenv([*:0]const u8) ?[*:0]const u8;
};
