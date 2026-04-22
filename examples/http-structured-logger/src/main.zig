//! HTTP structured logger plugin.
//!
//! Logs normalized HTTP request/response events and decoded response body
//! chunks. This is intended for end-to-end validation of the structured HTTP
//! runtime path under `qcontrol wrap`.

const std = @import("std");
const qcontrol = @import("qcontrol");

const ExchangeState = struct {
    allocator: std.mem.Allocator,
    method: []u8,
    raw_target: []u8,

    fn create(allocator: std.mem.Allocator, method: []const u8, raw_target: []const u8) ?*ExchangeState {
        const state = allocator.create(ExchangeState) catch return null;
        state.* = .{
            .allocator = allocator,
            .method = allocator.dupe(u8, method) catch {
                allocator.destroy(state);
                return null;
            },
            .raw_target = allocator.dupe(u8, raw_target) catch {
                allocator.free(state.method);
                allocator.destroy(state);
                return null;
            },
        };
        return state;
    }

    fn destroy(self: *ExchangeState) void {
        self.allocator.free(self.method);
        self.allocator.free(self.raw_target);
        self.allocator.destroy(self);
    }
};

var logger: qcontrol.Logger = .{};

fn onHttpRequest(ev: *qcontrol.http.RequestEvent) qcontrol.http.Action {
    logger.print("[http_structured_logger.zig] request(exchange={d}, method={s}, raw_target={s}, version={s})", .{
        ev.ctx().exchangeId(),
        ev.method(),
        ev.rawTarget(),
        @tagName(ev.ctx().version()),
    });

    const state = ExchangeState.create(std.heap.c_allocator, ev.method(), ev.rawTarget()) orelse return .pass;
    return .{ .state = state };
}

fn onHttpResponse(state_ptr: ?*anyopaque, ev: *qcontrol.http.ResponseEvent) qcontrol.http.Action {
    const state: ?*ExchangeState = if (state_ptr) |ptr| @ptrCast(@alignCast(ptr)) else null;

    logger.print("[http_structured_logger.zig] response(exchange={d}, method={s}, raw_target={s}, status={d}, version={s})", .{
        ev.ctx().exchangeId(),
        if (state) |s| s.method else "",
        if (state) |s| s.raw_target else "",
        ev.statusCode(),
        @tagName(ev.ctx().version()),
    });
    return .pass;
}

fn logBody(prefix: []const u8, ev: *qcontrol.http.BodyEvent) void {
    const body = ev.bytes();
    const allocator = std.heap.c_allocator;
    const body_hex = allocator.alloc(u8, body.len * 2) catch return;
    defer allocator.free(body_hex);
    const digits = "0123456789abcdef";
    for (body, 0..) |byte, idx| {
        body_hex[idx * 2] = digits[byte >> 4];
        body_hex[idx * 2 + 1] = digits[byte & 0x0f];
    }
    logger.print("[http_structured_logger.zig] {s}(exchange={d}, offset={d}, transfer_decoded={}, content_decoded={}, body_hex={s})", .{
        prefix,
        ev.ctx().exchangeId(),
        ev.offset(),
        ev.transferDecoded(),
        ev.contentDecoded(),
        body_hex,
    });
}

fn onHttpRequestBody(state_ptr: ?*anyopaque, ev: *qcontrol.http.BodyEvent) qcontrol.http.Action {
    _ = state_ptr;
    logBody("request_body", ev);
    return .pass;
}

fn onHttpResponseBody(state_ptr: ?*anyopaque, ev: *qcontrol.http.BodyEvent) qcontrol.http.Action {
    _ = state_ptr;
    logBody("response_body", ev);
    return .pass;
}

fn onHttpResponseDone(state_ptr: ?*anyopaque, ev: *qcontrol.http.MessageDoneEvent) void {
    _ = state_ptr;
    logger.print("[http_structured_logger.zig] response_done(exchange={d}, body_bytes={d})", .{
        ev.ctx().exchangeId(),
        ev.bodyBytes(),
    });
}

fn onHttpExchangeClose(state_ptr: ?*anyopaque, ev: *qcontrol.http.ExchangeCloseEvent) void {
    logger.print("[http_structured_logger.zig] exchange_close(exchange={d}, reason={s}, request_done={}, response_done={})", .{
        ev.ctx().exchangeId(),
        @tagName(ev.reason()),
        ev.requestDone(),
        ev.responseDone(),
    });

    if (state_ptr) |ptr| {
        const state: *ExchangeState = @ptrCast(@alignCast(ptr));
        state.destroy();
    }
}

fn init() void {
    logger.init();
    logger.print("[http_structured_logger.zig] initializing...", .{});
}

fn cleanup() void {
    logger.print("[http_structured_logger.zig] cleanup complete", .{});
    logger.deinit();
}

comptime {
    qcontrol.exportPlugin(.{
        .name = "zig_http_structured_logger",
        .on_init = init,
        .on_cleanup = cleanup,
        .on_http_request = onHttpRequest,
        .on_http_response = onHttpResponse,
        .on_http_request_body = onHttpRequestBody,
        .on_http_response_body = onHttpResponseBody,
        .on_http_response_done = onHttpResponseDone,
        .on_http_exchange_close = onHttpExchangeClose,
    });
}
