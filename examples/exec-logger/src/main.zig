//! Exec logger plugin - logs all exec operations to a file
//!
//! Demonstrates the v1 exec API. Note: exec hooks are not yet
//! implemented in the agent, so this plugin will compile but
//! the callbacks won't be invoked at runtime.
//!
//! Environment variables:
//!   QCONTROL_LOG_FILE - Path to log file (default: /tmp/qcontrol.log)

const std = @import("std");
const qcontrol = @import("qcontrol");

var logger: qcontrol.Logger = .{};

fn onExec(ev: *qcontrol.exec.Event) qcontrol.exec.ExecResult {
    // Log the exec event
    logger.print("[exec_logger.zig] exec(\"{s}\")", .{ev.path()});

    // Log arguments
    var arg_idx: usize = 0;
    var it = ev.argv();
    while (it.next()) |arg| : (arg_idx += 1) {
        logger.print("[exec_logger.zig]   argv[{d}] = \"{s}\"", .{ arg_idx, arg });
    }

    // Log cwd if set
    if (ev.cwd()) |cwd| {
        logger.print("[exec_logger.zig]   cwd = \"{s}\"", .{cwd});
    }

    return .pass;
}

fn onExecStdin(state: ?*anyopaque, ev: *qcontrol.exec.StdinEvent) qcontrol.exec.Action {
    _ = state;
    logger.print("[exec_logger.zig] stdin(pid={d}, count={d})", .{
        ev.pid(),
        ev.count(),
    });
    return .pass;
}

fn onExecStdout(state: ?*anyopaque, ev: *qcontrol.exec.StdoutEvent) qcontrol.exec.Action {
    _ = state;
    logger.print("[exec_logger.zig] stdout(pid={d}, count={d}) = {d}", .{
        ev.pid(),
        ev.count(),
        ev.result(),
    });
    return .pass;
}

fn onExecStderr(state: ?*anyopaque, ev: *qcontrol.exec.StderrEvent) qcontrol.exec.Action {
    _ = state;
    logger.print("[exec_logger.zig] stderr(pid={d}, count={d}) = {d}", .{
        ev.pid(),
        ev.count(),
        ev.result(),
    });
    return .pass;
}

fn onExecExit(state: ?*anyopaque, ev: *qcontrol.exec.ExitEvent) void {
    _ = state;
    if (ev.exitedNormally()) {
        logger.print("[exec_logger.zig] exit(pid={d}, code={d})", .{
            ev.pid(),
            ev.exitCode(),
        });
    } else {
        logger.print("[exec_logger.zig] exit(pid={d}, signal={d})", .{
            ev.pid(),
            ev.exitSignal(),
        });
    }
}

fn init() void {
    logger.init();
    logger.print("[exec_logger.zig] initializing...", .{});
}

fn cleanup() void {
    logger.print("[exec_logger.zig] cleanup complete", .{});
    logger.deinit();
}

comptime {
    qcontrol.exportPlugin(.{
        .name = "zig_exec_logger",
        .on_init = init,
        .on_cleanup = cleanup,
        .on_exec = onExec,
        .on_exec_stdin = onExecStdin,
        .on_exec_stdout = onExecStdout,
        .on_exec_stderr = onExecStderr,
        .on_exec_exit = onExecExit,
    });
}
