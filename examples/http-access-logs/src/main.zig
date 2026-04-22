//! HTTP access logs plugin - logs outbound HTTP connections by domain.
//!
//! This example tracks per-connection state until qcontrol discovers both the
//! target domain and the application protocol. Once the protocol is confirmed
//! to be HTTP, it emits a single access-log line for that connection.
//!
//! Environment variables:
//!   QCONTROL_LOG_FILE - Path to log file (default: /tmp/qcontrol.log)
//!   ACCESS_LOG_LEVEL - summary (default), headers, or full

const std = @import("std");
const qcontrol = @import("qcontrol");

const LogLevel = enum {
    summary,
    headers,
    full,

    fn fromEnv() LogLevel {
        const ptr = getenv("ACCESS_LOG_LEVEL");
        if (ptr) |value_ptr| {
            const value = std.mem.span(value_ptr);
            if (std.mem.eql(u8, value, "headers")) return .headers;
            if (std.mem.eql(u8, value, "full")) return .full;
        }
        return .summary;
    }
};

const ConnState = struct {
    allocator: std.mem.Allocator,
    domain: ?[]u8 = null,
    protocol: ?[]u8 = null,
    logged: bool = false,

    fn create(allocator: std.mem.Allocator) !*ConnState {
        const state = try allocator.create(ConnState);
        state.* = .{ .allocator = allocator };
        return state;
    }

    fn destroy(self: *ConnState) void {
        if (self.domain) |domain| self.allocator.free(domain);
        if (self.protocol) |protocol| self.allocator.free(protocol);
        self.allocator.destroy(self);
    }

    fn setDomain(self: *ConnState, domain: []const u8) !void {
        if (self.domain) |prev| self.allocator.free(prev);
        self.domain = try self.allocator.dupe(u8, domain);
    }

    fn setProtocol(self: *ConnState, protocol: []const u8) !void {
        if (self.protocol) |prev| self.allocator.free(prev);
        self.protocol = try self.allocator.dupe(u8, protocol);
    }
};

var logger: qcontrol.Logger = .{};
var log_level: LogLevel = .summary;

fn isHttpProtocol(protocol: []const u8) bool {
    return std.mem.startsWith(u8, protocol, "http/") or
        std.mem.eql(u8, protocol, "h2") or
        std.mem.eql(u8, protocol, "h3");
}

fn logPayload(direction: []const u8, fd: i32, data: []const u8) void {
    if (log_level != .full or data.len == 0) return;

    logger.print("[http_access_logs.zig] {s}(fd={d}, bytes={d}, data={s})", .{
        direction,
        fd,
        data.len,
        data,
    });
}

fn maybeLogHttpAccess(state: *ConnState, fd: i32) void {
    if (state.logged) return;

    const domain = state.domain orelse return;
    const protocol = state.protocol orelse return;
    if (!isHttpProtocol(protocol)) return;

    logger.print("[http_access_logs.zig] http_access(fd={d}, domain={s}, protocol={s})", .{
        fd,
        domain,
        protocol,
    });
    state.logged = true;
}

fn onNetConnect(ev: *qcontrol.net.ConnectEvent) qcontrol.net.ConnectResult {
    logger.print("[http_access_logs.zig] onNetConnect(fd={d})", .{ev.fd()});

    if (!ev.succeeded()) return .pass;

    const state = ConnState.create(std.heap.c_allocator) catch return .pass;
    return .{ .state = state };
}

fn onNetDomain(state_ptr: ?*anyopaque, ev: *qcontrol.net.DomainEvent) void {
    logger.print("[http_access_logs.zig] onNetDomain(fd={d}, domain={s})", .{ ev.fd(), ev.domain() });

    const state: *ConnState = @ptrCast(@alignCast(state_ptr orelse return));
    const domain = ev.domain();
    if (domain.len == 0) return;

    state.setDomain(domain) catch return;
    maybeLogHttpAccess(state, ev.fd());
}

fn onNetProtocol(state_ptr: ?*anyopaque, ev: *qcontrol.net.ProtocolEvent) void {
    logger.print("[http_access_logs.zig] onNetProtocol(fd={d}, protocol={s})", .{ ev.fd(), ev.protocol() });

    const state: *ConnState = @ptrCast(@alignCast(state_ptr orelse return));
    const protocol = ev.protocol();
    if (protocol.len == 0) return;

    state.setProtocol(protocol) catch return;
    maybeLogHttpAccess(state, ev.fd());
}

fn onNetSend(state_ptr: ?*anyopaque, ev: *qcontrol.net.SendEvent) qcontrol.net.Action {
    _ = state_ptr;
    logPayload("send", ev.fd(), ev.data());
    return .pass;
}

fn onNetRecv(state_ptr: ?*anyopaque, ev: *qcontrol.net.RecvEvent) qcontrol.net.Action {
    _ = state_ptr;
    if (ev.data()) |data| {
        logPayload("recv", ev.fd(), data);
    }
    return .pass;
}

fn onNetClose(state_ptr: ?*anyopaque, ev: *qcontrol.net.CloseEvent) void {
    _ = ev;
    const state: *ConnState = @ptrCast(@alignCast(state_ptr orelse return));
    state.destroy();
}

fn init() void {
    logger.init();
    log_level = LogLevel.fromEnv();
    logger.print("[http_access_logs.zig] initializing (access_log_level={s})", .{
        @tagName(log_level),
    });
}

fn cleanup() void {
    logger.print("[http_access_logs.zig] cleanup complete", .{});
    logger.deinit();
}

extern fn getenv([*:0]const u8) ?[*:0]const u8;

comptime {
    qcontrol.exportPlugin(.{
        .name = "zig_http_access_logs",
        .on_init = init,
        .on_cleanup = cleanup,
        .on_net_connect = onNetConnect,
        .on_net_domain = onNetDomain,
        .on_net_protocol = onNetProtocol,
        .on_net_send = onNetSend,
        .on_net_recv = onNetRecv,
        .on_net_close = onNetClose,
    });
}
