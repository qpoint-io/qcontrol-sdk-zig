//! Access control plugin - blocks access to /tmp/secret* paths
//!
//! Environment variables:
//!   QCONTROL_LOG_FILE - Path to log file (default: /tmp/qcontrol.log)

const std = @import("std");
const qcontrol = @import("qcontrol");

var logger: qcontrol.Logger = .{};

fn onFileOpen(ev: *qcontrol.file.OpenEvent) qcontrol.file.OpenResult {
    const path = ev.path();
    if (std.mem.startsWith(u8, path, "/tmp/secret")) {
        logger.print("[access_control.zig] BLOCKED: {s}", .{path});
        return .block;
    }
    return .pass;
}

fn init() void {
    logger.init();
    logger.print("[access_control.zig] initializing - blocking /tmp/secret*", .{});
}

fn cleanup() void {
    logger.deinit();
}

comptime {
    qcontrol.exportPlugin(.{
        .name = "zig_access_control",
        .on_init = init,
        .on_cleanup = cleanup,
        .on_file_open = onFileOpen,
    });
}
