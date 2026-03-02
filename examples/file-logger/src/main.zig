//! File logger plugin - logs all file operations to a file
//!
//! Environment variables:
//!   QCONTROL_LOG_FILE - Path to log file (default: /tmp/qcontrol.log)

const std = @import("std");
const qcontrol = @import("qcontrol");

var logger: qcontrol.Logger = .{};

fn onFileOpen(ev: *qcontrol.file.OpenEvent) qcontrol.file.OpenResult {
    logger.print("[file_logger.zig] open(\"{s}\", 0x{x}) = {d}", .{
        ev.path(),
        ev.flags(),
        ev.result(),
    });
    return .pass;
}

fn onFileRead(state: ?*anyopaque, ev: *qcontrol.file.ReadEvent) qcontrol.file.Action {
    _ = state;
    logger.print("[file_logger.zig] read({d}, buf, {d}) = {d}", .{
        ev.fd(),
        ev.count(),
        ev.result(),
    });
    return .pass;
}

fn onFileWrite(state: ?*anyopaque, ev: *qcontrol.file.WriteEvent) qcontrol.file.Action {
    _ = state;
    logger.print("[file_logger.zig] write({d}, buf, {d}) = {d}", .{
        ev.fd(),
        ev.count(),
        ev.result(),
    });
    return .pass;
}

fn onFileClose(state: ?*anyopaque, ev: *qcontrol.file.CloseEvent) void {
    _ = state;
    logger.print("[file_logger.zig] close({d}) = {d}", .{
        ev.fd(),
        ev.result(),
    });
}

fn init() void {
    logger.init();
    logger.print("[file_logger.zig] initializing...", .{});
}

fn cleanup() void {
    logger.print("[file_logger.zig] cleanup complete", .{});
    logger.deinit();
}

comptime {
    qcontrol.exportPlugin(.{
        .name = "zig_file_logger",
        .on_init = init,
        .on_cleanup = cleanup,
        .on_file_open = onFileOpen,
        .on_file_read = onFileRead,
        .on_file_write = onFileWrite,
        .on_file_close = onFileClose,
    });
}
