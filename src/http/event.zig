//! HTTP event wrappers around the C ABI.

const std = @import("std");
const ffi = @import("../ffi.zig");
const action = @import("action.zig");
const session = @import("session.zig");
const file = @import("../file/mod.zig");

fn bytesFromPtrLen(ptr: ?[*]const u8, len: usize) []const u8 {
    if (ptr) |p| {
        if (len > 0) return p[0..len];
    }
    return "";
}

/// Single HTTP header view.
pub const Header = struct {
    raw: *const ffi.c.qcontrol_http_header_t,

    pub fn name(self: *const Header) []const u8 {
        return bytesFromPtrLen(@ptrCast(self.raw.name), self.raw.name_len);
    }

    pub fn value(self: *const Header) []const u8 {
        return bytesFromPtrLen(@ptrCast(self.raw.value), self.raw.value_len);
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

/// Mutable header block backed by the host/runtime.
pub const HeaderBlock = struct {
    raw: *ffi.c.qcontrol_http_headers_t,

    pub fn len(self: *const HeaderBlock) usize {
        return ffi.c.qcontrol_http_headers_count(self.raw);
    }

    pub fn isEmpty(self: *const HeaderBlock) bool {
        return self.len() == 0;
    }

    pub fn list(self: *const HeaderBlock) HeaderList {
        return .{
            .raw = ffi.c.qcontrol_http_headers_data(self.raw),
            .count = ffi.c.qcontrol_http_headers_count(self.raw),
        };
    }

    pub fn get(self: *const HeaderBlock, name: []const u8) ?[]const u8 {
        var iter = self.list().iterator();
        while (iter.next()) |header| {
            if (std.ascii.eqlIgnoreCase(header.name(), name)) {
                return header.value();
            }
        }
        return null;
    }

    pub fn add(self: *HeaderBlock, name: []const u8, value: []const u8) bool {
        return ffi.c.qcontrol_http_headers_add(self.raw, name.ptr, name.len, value.ptr, value.len) == 0;
    }

    pub fn set(self: *HeaderBlock, name: []const u8, value: []const u8) bool {
        return ffi.c.qcontrol_http_headers_set(self.raw, name.ptr, name.len, value.ptr, value.len) == 0;
    }

    pub fn remove(self: *HeaderBlock, name: []const u8) usize {
        return ffi.c.qcontrol_http_headers_remove(self.raw, name.ptr, name.len);
    }
};

/// Mutable request head handle supplied by hosts that support head edits.
pub const RequestHead = struct {
    raw: *ffi.c.qcontrol_http_request_head_t,

    pub fn rawTarget(self: *const RequestHead) []const u8 {
        return bytesFromPtrLen(@ptrCast(ffi.c.qcontrol_http_request_raw_target(self.raw)), ffi.c.qcontrol_http_request_raw_target_len(self.raw));
    }

    pub fn method(self: *const RequestHead) []const u8 {
        return bytesFromPtrLen(@ptrCast(ffi.c.qcontrol_http_request_method(self.raw)), ffi.c.qcontrol_http_request_method_len(self.raw));
    }

    pub fn setMethod(self: *RequestHead, value: []const u8) bool {
        return ffi.c.qcontrol_http_request_set_method(self.raw, value.ptr, value.len) == 0;
    }

    pub fn scheme(self: *const RequestHead) ?[]const u8 {
        const value = bytesFromPtrLen(@ptrCast(ffi.c.qcontrol_http_request_scheme(self.raw)), ffi.c.qcontrol_http_request_scheme_len(self.raw));
        if (value.len == 0) return null;
        return value;
    }

    pub fn setScheme(self: *RequestHead, value: []const u8) bool {
        return ffi.c.qcontrol_http_request_set_scheme(self.raw, value.ptr, value.len) == 0;
    }

    pub fn authority(self: *const RequestHead) ?[]const u8 {
        const value = bytesFromPtrLen(@ptrCast(ffi.c.qcontrol_http_request_authority(self.raw)), ffi.c.qcontrol_http_request_authority_len(self.raw));
        if (value.len == 0) return null;
        return value;
    }

    pub fn setAuthority(self: *RequestHead, value: []const u8) bool {
        return ffi.c.qcontrol_http_request_set_authority(self.raw, value.ptr, value.len) == 0;
    }

    pub fn path(self: *const RequestHead) []const u8 {
        return bytesFromPtrLen(@ptrCast(ffi.c.qcontrol_http_request_path(self.raw)), ffi.c.qcontrol_http_request_path_len(self.raw));
    }

    pub fn setPath(self: *RequestHead, value: []const u8) bool {
        return ffi.c.qcontrol_http_request_set_path(self.raw, value.ptr, value.len) == 0;
    }

    pub fn headers(self: *RequestHead) HeaderBlock {
        // Hosts only surface a mutable request head when they can also surface
        // the backing header block for that head.
        return .{ .raw = ffi.c.qcontrol_http_request_headers(self.raw) orelse unreachable };
    }
};

/// Mutable response head handle supplied by hosts that support head edits.
pub const ResponseHead = struct {
    raw: *ffi.c.qcontrol_http_response_head_t,

    pub fn statusCode(self: *const ResponseHead) u16 {
        return ffi.c.qcontrol_http_response_status_code(self.raw);
    }

    pub fn setStatusCode(self: *ResponseHead, status_code: u16) void {
        ffi.c.qcontrol_http_response_set_status_code(self.raw, status_code);
    }

    pub fn reason(self: *const ResponseHead) ?[]const u8 {
        const value = bytesFromPtrLen(@ptrCast(ffi.c.qcontrol_http_response_reason(self.raw)), ffi.c.qcontrol_http_response_reason_len(self.raw));
        if (value.len == 0) return null;
        return value;
    }

    pub fn setReason(self: *ResponseHead, value: []const u8) bool {
        return ffi.c.qcontrol_http_response_set_reason(self.raw, value.ptr, value.len) == 0;
    }

    pub fn headers(self: *ResponseHead) HeaderBlock {
        // Hosts only surface a mutable response head when they can also surface
        // the backing header block for that head.
        return .{ .raw = ffi.c.qcontrol_http_response_headers(self.raw) orelse unreachable };
    }
};

pub const RequestEvent = struct {
    raw: *ffi.c.qcontrol_http_request_event_t,

    pub fn ctx(self: *const RequestEvent) session.Ctx {
        return .{ .raw = &self.raw.ctx };
    }

    pub fn rawTarget(self: *const RequestEvent) []const u8 {
        return bytesFromPtrLen(@ptrCast(self.raw.raw_target), self.raw.raw_target_len);
    }

    pub fn method(self: *const RequestEvent) []const u8 {
        return bytesFromPtrLen(@ptrCast(self.raw.method), self.raw.method_len);
    }

    pub fn scheme(self: *const RequestEvent) ?[]const u8 {
        const value = bytesFromPtrLen(@ptrCast(self.raw.scheme), self.raw.scheme_len);
        if (value.len == 0) return null;
        return value;
    }

    pub fn authority(self: *const RequestEvent) ?[]const u8 {
        const value = bytesFromPtrLen(@ptrCast(self.raw.authority), self.raw.authority_len);
        if (value.len == 0) return null;
        return value;
    }

    pub fn path(self: *const RequestEvent) []const u8 {
        return bytesFromPtrLen(@ptrCast(self.raw.path), self.raw.path_len);
    }

    pub fn headers(self: *const RequestEvent) HeaderList {
        return .{
            .raw = self.raw.headers,
            .count = self.raw.header_count,
        };
    }

    pub fn head(self: *RequestEvent) ?RequestHead {
        if (self.raw.head == null) return null;
        return .{ .raw = self.raw.head.? };
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
        const value = bytesFromPtrLen(@ptrCast(self.raw.reason), self.raw.reason_len);
        if (value.len == 0) return null;
        return value;
    }

    pub fn headers(self: *const ResponseEvent) HeaderList {
        return .{
            .raw = self.raw.headers,
            .count = self.raw.header_count,
        };
    }

    pub fn head(self: *ResponseEvent) ?ResponseHead {
        if (self.raw.head == null) return null;
        return .{ .raw = self.raw.head.? };
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
        return bytesFromPtrLen(@ptrCast(self.raw.bytes), self.raw.bytes_len);
    }

    pub fn body(self: *BodyEvent) ?file.Buffer {
        if (self.raw.body == null) return null;
        return .{ .raw = self.raw.body.? };
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

    pub fn endOfStream(self: *const BodyEvent) bool {
        return self.raw.end_of_stream != 0;
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

    pub fn headerBlock(self: *TrailersEvent) ?HeaderBlock {
        if (self.raw.header_block == null) return null;
        return .{ .raw = self.raw.header_block.? };
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
