//! Net transform plugin - demonstrates modifying plaintext network traffic.
//!
//! This example is intended for `qcontrol wrap`.
//! It rewrites simple text responses by replacing:
//!   "hello"  -> "hullo"
//!   "server" -> "client"
//!
//! The transform is deliberately simple and best demonstrated against a local
//! text-based HTTP server such as `../test-net-transform.sh`.
//!
//! Environment variables:
//!   QCONTROL_LOG_FILE - Path to log file (default: /tmp/qcontrol.log)

const std = @import("std");
const qcontrol = @import("qcontrol");

var logger: qcontrol.Logger = .{};

fn onNetConnect(ev: *qcontrol.net.ConnectEvent) qcontrol.net.ConnectResult {
    if (!ev.succeeded()) return .pass;

    logger.print("[net_transform.zig] intercepting {s}:{d}", .{
        ev.dstAddr(),
        ev.dstPort(),
    });

    return .{ .session = .{
        .recv_config = .{
            .replace = qcontrol.net.patterns(&.{
                .{ "hello", "hullo" },
                .{ "server", "client" },
            }),
        },
    } };
}

fn onNetDomain(state: ?*anyopaque, ev: *qcontrol.net.DomainEvent) void {
    _ = state;
    logger.print("[net_transform.zig] domain(fd={d}, domain={s})", .{
        ev.fd(),
        ev.domain(),
    });
}

fn onNetClose(state: ?*anyopaque, ev: *qcontrol.net.CloseEvent) void {
    _ = state;
    logger.print("[net_transform.zig] close(fd={d}) = {d}", .{
        ev.fd(),
        ev.result(),
    });
}

fn init() void {
    logger.init();
    logger.print("[net_transform.zig] initializing...", .{});
}

fn cleanup() void {
    logger.print("[net_transform.zig] cleanup complete", .{});
    logger.deinit();
}

comptime {
    qcontrol.exportPlugin(.{
        .name = "zig_net_transform",
        .on_init = init,
        .on_cleanup = cleanup,
        .on_net_connect = onNetConnect,
        .on_net_domain = onNetDomain,
        .on_net_close = onNetClose,
    });
}
