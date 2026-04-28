//! HTTP rewrite plugin example.
//!
//! Demonstrates the mutable Zig HTTP SDK surface:
//! - request header normalization through the mutable request head
//! - response header mutation
//! - explicit buffered-body scheduling from the response callback
//! - full-body replacement on the terminal response body callback

const std = @import("std");
const qcontrol = @import("qcontrol");

const ExchangeState = struct {
    rewrite_response: bool,
};

/// Normalize request headers and decide whether the response body should be rewritten.
fn onHttpRequest(ev: *qcontrol.http.RequestEvent) qcontrol.http.Action {
    if (ev.head()) |head_value| {
        var head = head_value;
        var headers = head.headers();
        _ = headers.remove("proxy-connection");
        _ = headers.set("x-qcontrol", "1");
    }

    const state = std.heap.c_allocator.create(ExchangeState) catch return .block;
    state.* = .{
        .rewrite_response = std.mem.eql(u8, ev.path(), "/api/profile"),
    };
    return .{ .state = state };
}

/// Rewrite response headers and request buffered-body scheduling when needed.
fn onHttpResponse(state_ptr: ?*anyopaque, ev: *qcontrol.http.ResponseEvent) qcontrol.http.Action {
    const state: *ExchangeState = @ptrCast(@alignCast(state_ptr orelse return .pass));
    if (!state.rewrite_response) return .pass;

    if (ev.head()) |head_value| {
        var head = head_value;
        var headers = head.headers();
        _ = headers.set("content-type", "application/json");
    }

    return (qcontrol.http.Action{ .pass = {} }).withBodyMode(.buffer);
}

/// Replace the buffered JSON response body on the terminal response body callback.
fn onHttpResponseBody(state_ptr: ?*anyopaque, ev: *qcontrol.http.BodyEvent) qcontrol.http.Action {
    const state: *ExchangeState = @ptrCast(@alignCast(state_ptr orelse return .pass));
    if (!state.rewrite_response or !ev.endOfStream()) return .pass;

    if (ev.body()) |body_value| {
        var body = body_value;
        body.set("{\"rewritten\":true}");
    }

    return .pass;
}

/// Release per-exchange state after the exchange lifecycle completes.
fn onHttpExchangeClose(state_ptr: ?*anyopaque, ev: *qcontrol.http.ExchangeCloseEvent) void {
    _ = ev;
    if (state_ptr) |ptr| {
        const state: *ExchangeState = @ptrCast(@alignCast(ptr));
        std.heap.c_allocator.destroy(state);
    }
}

comptime {
    qcontrol.exportPlugin(.{
        .name = "zig_http_rewrite",
        .on_http_request = onHttpRequest,
        .on_http_response = onHttpResponse,
        .on_http_response_body = onHttpResponseBody,
        .on_http_exchange_close = onHttpExchangeClose,
    });
}
