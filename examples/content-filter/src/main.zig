//! Content filter plugin - redacts sensitive data in .txt and .log files
//!
//! Demonstrates session configuration with buffer transforms.
//! Uses OpenResult.session with RwConfig for pattern replacement.
//!
//! Environment variables:
//!   QCONTROL_LOG_FILE - Path to log file (default: /tmp/qcontrol.log)

const std = @import("std");
const qcontrol = @import("qcontrol");

/// Per-file state for tracking filter activity.
const FilterState = struct {
    path: []u8,
    allocator: std.mem.Allocator,

    fn create(allocator: std.mem.Allocator, path: []const u8) !*FilterState {
        const state = try allocator.create(FilterState);
        state.* = .{
            .path = try allocator.dupe(u8, path),
            .allocator = allocator,
        };
        return state;
    }

    fn destroy(self: *FilterState) void {
        self.allocator.free(self.path);
        self.allocator.destroy(self);
    }
};

var logger: qcontrol.Logger = .{};

fn onFileOpen(ev: *qcontrol.file.OpenEvent) qcontrol.file.OpenResult {
    // Only filter successfully opened files
    if (!ev.succeeded()) return .pass;

    const path = ev.path();

    // Only filter .txt and .log files
    const is_txt = std.mem.endsWith(u8, path, ".txt");
    const is_log = std.mem.endsWith(u8, path, ".log");

    if (!is_txt and !is_log) return .pass;

    // Create state to track this file
    const state = FilterState.create(std.heap.c_allocator, path) catch return .pass;
    logger.print("[content_filter] filtering: {s}", .{path});

    // Return .session with read transforms
    return .{ .session = .{
        .state = state,
        .file_read = .{
            // Static prefix added to all reads
            .prefix = "[FILTERED]\n",
            // Pattern replacements for sensitive data
            .replace = qcontrol.file.patterns(&.{
                .{ "password", "********" },
                .{ "secret", "[REDACTED]" },
                .{ "api_key", "[HIDDEN]" },
                .{ "token", "[HIDDEN]" },
            }),
        },
    } };
}

fn onFileClose(state: ?*anyopaque, ev: *qcontrol.file.CloseEvent) void {
    _ = ev;
    if (state) |s| {
        const filter_state: *FilterState = @ptrCast(@alignCast(s));
        logger.print("[content_filter] closed: {s}", .{filter_state.path});
        filter_state.destroy();
    }
}

fn init() void {
    logger.init();
    logger.print("[content_filter] initializing...", .{});
}

fn cleanup() void {
    logger.print("[content_filter] cleanup complete", .{});
    logger.deinit();
}

comptime {
    qcontrol.exportPlugin(.{
        .name = "zig_content_filter",
        .on_init = init,
        .on_cleanup = cleanup,
        .on_file_open = onFileOpen,
        .on_file_close = onFileClose,
        // Note: on_file_read/on_file_write not needed - transforms are
        // handled declaratively via the session config returned from on_file_open
    });
}
