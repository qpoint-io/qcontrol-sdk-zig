//! HTTP event wrappers around the C ABI.

const ffi = @import("../ffi.zig");
const action = @import("action.zig");
const session = @import("session.zig");

/// Single HTTP header view.
pub const Header = struct {
    raw: *const ffi.c.qcontrol_http_header_t,

    pub fn name(self: *const Header) []const u8 {
        if (self.raw.name) |ptr| {
            return ptr[0..self.raw.name_len];
        }
        return "";
    }

    pub fn value(self: *const Header) []const u8 {
        if (self.raw.value) |ptr| {
            return ptr[0..self.raw.value_len];
        }
        return "";
    }
};

/// Lightweight header-list view.
pub const HeaderList = struct {
    raw: ?[*]const ffi.c.qcontrol_http_header_t,
    count: usize,

    pub fn len(self: *const HeaderList) usize {
        return self.count;
    }

    pub fn isEmpty(self: *const HeaderList) bool {
        return self.count == 0;
    }

    pub fn at(self: *const HeaderList, index: usize) ?Header {
        if (index >= self.count) return null;
        const ptr = self.raw orelse return null;
        return .{ .raw = &ptr[index] };
    }

    pub fn iterator(self: HeaderList) HeaderIterator {
        return .{ .headers = self };
    }
};

pub const HeaderIterator = struct {
    headers: HeaderList,
    index: usize = 0,

    pub fn next(self: *HeaderIterator) ?Header {
        defer self.index += 1;
        return self.headers.at(self.index);
    }
};

pub const RequestEvent = struct {
    raw: *ffi.c.qcontrol_http_request_event_t,

    pub fn ctx(self: *const RequestEvent) session.Ctx {
        return .{ .raw = &self.raw.ctx };
    }

    pub fn rawTarget(self: *const RequestEvent) []const u8 {
        if (self.raw.raw_target) |ptr| {
            return ptr[0..self.raw.raw_target_len];
        }
        return "";
    }

    pub fn method(self: *const RequestEvent) []const u8 {
        if (self.raw.method) |ptr| {
            return ptr[0..self.raw.method_len];
        }
        return "";
    }

    pub fn scheme(self: *const RequestEvent) ?[]const u8 {
        if (self.raw.scheme) |ptr| {
            if (self.raw.scheme_len > 0) return ptr[0..self.raw.scheme_len];
        }
        return null;
    }

    pub fn authority(self: *const RequestEvent) ?[]const u8 {
        if (self.raw.authority) |ptr| {
            if (self.raw.authority_len > 0) return ptr[0..self.raw.authority_len];
        }
        return null;
    }

    pub fn path(self: *const RequestEvent) []const u8 {
        if (self.raw.path) |ptr| {
            return ptr[0..self.raw.path_len];
        }
        return "";
    }

    pub fn headers(self: *const RequestEvent) HeaderList {
        return .{
            .raw = self.raw.headers,
            .count = self.raw.header_count,
        };
    }
};

pub const ResponseEvent = struct {
    raw: *ffi.c.qcontrol_http_response_event_t,

    pub fn ctx(self: *const ResponseEvent) session.Ctx {
        return .{ .raw = &self.raw.ctx };
    }

    pub fn statusCode(self: *const ResponseEvent) u16 {
        return self.raw.status_code;
    }

    pub fn reason(self: *const ResponseEvent) ?[]const u8 {
        if (self.raw.reason) |ptr| {
            if (self.raw.reason_len > 0) return ptr[0..self.raw.reason_len];
        }
        return null;
    }

    pub fn headers(self: *const ResponseEvent) HeaderList {
        return .{
            .raw = self.raw.headers,
            .count = self.raw.header_count,
        };
    }
};

pub const BodyEvent = struct {
    raw: *ffi.c.qcontrol_http_body_event_t,

    pub fn ctx(self: *const BodyEvent) session.Ctx {
        return .{ .raw = &self.raw.ctx };
    }

    pub fn kind(self: *const BodyEvent) action.MessageKind {
        return action.MessageKind.fromC(self.raw.kind);
    }

    pub fn bytes(self: *const BodyEvent) []const u8 {
        if (self.raw.bytes) |ptr| {
            if (self.raw.bytes_len > 0) return ptr[0..self.raw.bytes_len];
        }
        return "";
    }

    pub fn offset(self: *const BodyEvent) u64 {
        return self.raw.offset;
    }

    pub fn flags(self: *const BodyEvent) u32 {
        return self.raw.flags;
    }

    pub fn transferDecoded(self: *const BodyEvent) bool {
        return (self.raw.flags & ffi.c.QCONTROL_HTTP_BODY_FLAG_TRANSFER_DECODED) != 0;
    }

    pub fn contentDecoded(self: *const BodyEvent) bool {
        return (self.raw.flags & ffi.c.QCONTROL_HTTP_BODY_FLAG_CONTENT_DECODED) != 0;
    }
};

pub const TrailersEvent = struct {
    raw: *ffi.c.qcontrol_http_trailers_event_t,

    pub fn ctx(self: *const TrailersEvent) session.Ctx {
        return .{ .raw = &self.raw.ctx };
    }

    pub fn kind(self: *const TrailersEvent) action.MessageKind {
        return action.MessageKind.fromC(self.raw.kind);
    }

    pub fn headers(self: *const TrailersEvent) HeaderList {
        return .{
            .raw = self.raw.headers,
            .count = self.raw.header_count,
        };
    }
};

pub const MessageDoneEvent = struct {
    raw: *ffi.c.qcontrol_http_message_done_event_t,

    pub fn ctx(self: *const MessageDoneEvent) session.Ctx {
        return .{ .raw = &self.raw.ctx };
    }

    pub fn kind(self: *const MessageDoneEvent) action.MessageKind {
        return action.MessageKind.fromC(self.raw.kind);
    }

    pub fn bodyBytes(self: *const MessageDoneEvent) u64 {
        return self.raw.body_bytes;
    }
};

pub const ExchangeCloseEvent = struct {
    raw: *ffi.c.qcontrol_http_exchange_close_event_t,

    pub fn ctx(self: *const ExchangeCloseEvent) session.Ctx {
        return .{ .raw = &self.raw.ctx };
    }

    pub fn reason(self: *const ExchangeCloseEvent) action.CloseReason {
        return action.CloseReason.fromC(self.raw.reason);
    }

    pub fn flags(self: *const ExchangeCloseEvent) u32 {
        return self.raw.flags;
    }

    pub fn requestDone(self: *const ExchangeCloseEvent) bool {
        return (self.raw.flags & ffi.c.QCONTROL_HTTP_EXCHANGE_FLAG_REQUEST_DONE) != 0;
    }

    pub fn responseDone(self: *const ExchangeCloseEvent) bool {
        return (self.raw.flags & ffi.c.QCONTROL_HTTP_EXCHANGE_FLAG_RESPONSE_DONE) != 0;
    }
};
