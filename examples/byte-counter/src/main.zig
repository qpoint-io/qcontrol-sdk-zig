//! Byte counter plugin - tracks bytes read/written per file
//!
//! Demonstrates per-file state tracking without transforms.
//! Uses OpenResult.state to attach custom state to each file.
//!
//! Environment variables:
//!   QCONTROL_LOG_FILE - Path to log file (default: /tmp/qcontrol.log)

const std = @import("std");
const qcontrol = @import("qcontrol");

/// Per-file statistics tracked from open to close.
const FileStats = struct {
    path: []u8,
    bytes_read: usize = 0,
    bytes_written: usize = 0,
    read_calls: usize = 0,
    write_calls: usize = 0,
    allocator: std.mem.Allocator,

    fn create(allocator: std.mem.Allocator, path: []const u8) !*FileStats {
        const stats = try allocator.create(FileStats);
        stats.* = .{
            .path = try allocator.dupe(u8, path),
            .allocator = allocator,
        };
        return stats;
    }

    fn destroy(self: *FileStats) void {
        self.allocator.free(self.path);
        self.allocator.destroy(self);
    }
};

var logger: qcontrol.Logger = .{};

fn onFileOpen(ev: *qcontrol.file.OpenEvent) qcontrol.file.OpenResult {
    // Only track successfully opened files
    if (!ev.succeeded()) return .pass;

    // Skip common paths to reduce noise
    const path = ev.path();
    if (std.mem.startsWith(u8, path, "/proc/") or
        std.mem.startsWith(u8, path, "/sys/") or
        std.mem.startsWith(u8, path, "/dev/"))
    {
        return .pass;
    }

    // Create state to track this file
    const stats = FileStats.create(std.heap.c_allocator, path) catch return .pass;
    logger.print("[byte_counter] tracking: {s}", .{path});

    // Return .state to track without transforms
    return .{ .state = stats };
}

fn onFileRead(state: ?*anyopaque, ev: *qcontrol.file.ReadEvent) qcontrol.file.Action {
    if (state) |s| {
        const stats: *FileStats = @ptrCast(@alignCast(s));
        const bytes: isize = ev.result();
        if (bytes > 0) {
            stats.bytes_read += @intCast(bytes);
            stats.read_calls += 1;
        }
    }
    return .pass;
}

fn onFileWrite(state: ?*anyopaque, ev: *qcontrol.file.WriteEvent) qcontrol.file.Action {
    if (state) |s| {
        const stats: *FileStats = @ptrCast(@alignCast(s));
        const bytes: isize = ev.result();
        if (bytes > 0) {
            stats.bytes_written += @intCast(bytes);
            stats.write_calls += 1;
        }
    }
    return .pass;
}

fn onFileClose(state: ?*anyopaque, ev: *qcontrol.file.CloseEvent) void {
    _ = ev;
    if (state) |s| {
        const stats: *FileStats = @ptrCast(@alignCast(s));

        // Report statistics on close
        logger.print("[byte_counter] {s}: read {d} bytes ({d} calls), wrote {d} bytes ({d} calls)", .{
            stats.path,
            stats.bytes_read,
            stats.read_calls,
            stats.bytes_written,
            stats.write_calls,
        });

        // Clean up state
        stats.destroy();
    }
}

fn init() void {
    logger.init();
    logger.print("[byte_counter] initializing...", .{});
}

fn cleanup() void {
    logger.print("[byte_counter] cleanup complete", .{});
    logger.deinit();
}

comptime {
    qcontrol.exportPlugin(.{
        .name = "zig_byte_counter",
        .on_init = init,
        .on_cleanup = cleanup,
        .on_file_open = onFileOpen,
        .on_file_read = onFileRead,
        .on_file_write = onFileWrite,
        .on_file_close = onFileClose,
    });
}

// Note: All callbacks (on_file_read, on_file_write, on_file_close) are needed
// here because we track state and need to observe all operations.
