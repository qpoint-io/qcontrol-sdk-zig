//! Net logger plugin - logs all network operations to a file.
//!
//! This plugin is useful with `qcontrol wrap`, where wrapped HTTP and HTTPS
//! traffic is normalized into the network ABI and routed through these
//! callbacks. Native agent-side net hooks are still under development, but the
//! current implementation already exercises the same plugin-facing ABI.
//!
//! Environment variables:
//!   QCONTROL_LOG_FILE - Path to log file (default: /tmp/qcontrol.log)

const std = @import("std");
const qcontrol = @import("qcontrol");

var logger: qcontrol.Logger = .{};
var tracked_state: u8 = 0;

fn onNetConnect(ev: *qcontrol.net.ConnectEvent) qcontrol.net.ConnectResult {
    logger.print("[net_logger.zig] connect(fd={d}, dst={s}:{d}) = {d}", .{
        ev.fd(),
        ev.dstAddr(),
        ev.dstPort(),
        ev.result(),
    });

    if (ev.srcAddr()) |src| {
        logger.print("[net_logger.zig]   src={s}:{d}", .{ src, ev.srcPort() });
    }

    return .{ .state = &tracked_state };
}

fn onNetAccept(ev: *qcontrol.net.AcceptEvent) qcontrol.net.AcceptResult {
    logger.print("[net_logger.zig] accept(fd={d}, listen_fd={d}, src={s}:{d}) = {d}", .{
        ev.fd(),
        ev.listenFd(),
        ev.srcAddr(),
        ev.srcPort(),
        ev.result(),
    });
    return .{ .state = &tracked_state };
}

fn onNetTls(state: ?*anyopaque, ev: *qcontrol.net.TlsEvent) void {
    _ = state;
    logger.print("[net_logger.zig] tls(fd={d}, version={s})", .{
        ev.fd(),
        ev.version(),
    });
    if (ev.cipher()) |cipher| {
        logger.print("[net_logger.zig]   cipher={s}", .{cipher});
    }
}

fn onNetDomain(state: ?*anyopaque, ev: *qcontrol.net.DomainEvent) void {
    _ = state;
    logger.print("[net_logger.zig] domain(fd={d}, domain={s})", .{
        ev.fd(),
        ev.domain(),
    });
}

fn onNetProtocol(state: ?*anyopaque, ev: *qcontrol.net.ProtocolEvent) void {
    _ = state;
    logger.print("[net_logger.zig] protocol(fd={d}, protocol={s})", .{
        ev.fd(),
        ev.protocol(),
    });
}

fn onNetSend(state: ?*anyopaque, ev: *qcontrol.net.SendEvent) qcontrol.net.Action {
    _ = state;
    logger.print("[net_logger.zig] send(fd={d}, count={d})", .{
        ev.fd(),
        ev.count(),
    });
    return .pass;
}

fn onNetRecv(state: ?*anyopaque, ev: *qcontrol.net.RecvEvent) qcontrol.net.Action {
    _ = state;
    logger.print("[net_logger.zig] recv(fd={d}, count={d}) = {d}", .{
        ev.fd(),
        ev.count(),
        ev.result(),
    });
    return .pass;
}

fn onNetClose(state: ?*anyopaque, ev: *qcontrol.net.CloseEvent) void {
    _ = state;
    logger.print("[net_logger.zig] close(fd={d}) = {d}", .{
        ev.fd(),
        ev.result(),
    });
}

fn init() void {
    logger.init();
    logger.print("[net_logger.zig] initializing...", .{});
}

fn cleanup() void {
    logger.print("[net_logger.zig] cleanup complete", .{});
    logger.deinit();
}

comptime {
    qcontrol.exportPlugin(.{
        .name = "zig_net_logger",
        .on_init = init,
        .on_cleanup = cleanup,
        .on_net_connect = onNetConnect,
        .on_net_accept = onNetAccept,
        .on_net_tls = onNetTls,
        .on_net_domain = onNetDomain,
        .on_net_protocol = onNetProtocol,
        .on_net_send = onNetSend,
        .on_net_recv = onNetRecv,
        .on_net_close = onNetClose,
    });
}
