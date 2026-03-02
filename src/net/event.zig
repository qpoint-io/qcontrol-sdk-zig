//! Network event types wrapping C event structs.
//!
//! These provide idiomatic Zig accessors for the raw C event data.

const std = @import("std");
const ffi = @import("../ffi.zig");

// =============================================================================
// ConnectEvent - Event for on_net_connect
// =============================================================================

/// Event passed to on_net_connect callback.
/// Outbound connection being established.
pub const ConnectEvent = struct {
    raw: *ffi.c.qcontrol_net_connect_event_t,

    /// Get the socket file descriptor.
    pub fn fd(self: *const ConnectEvent) i32 {
        return self.raw.fd;
    }

    /// Get the destination address (IP string).
    pub fn dstAddr(self: *const ConnectEvent) []const u8 {
        if (self.raw.dst_addr) |a| {
            return a[0..self.raw.dst_addr_len];
        }
        return "";
    }

    /// Get the destination port.
    pub fn dstPort(self: *const ConnectEvent) u16 {
        return self.raw.dst_port;
    }

    /// Get the local source address (may be empty if not bound).
    pub fn srcAddr(self: *const ConnectEvent) ?[]const u8 {
        if (self.raw.src_addr) |a| {
            if (self.raw.src_addr_len > 0) {
                return a[0..self.raw.src_addr_len];
            }
        }
        return null;
    }

    /// Get the local source port (0 if not bound).
    pub fn srcPort(self: *const ConnectEvent) u16 {
        return self.raw.src_port;
    }

    /// Get the result (0 on success, -errno on failure).
    pub fn result(self: *const ConnectEvent) i32 {
        return self.raw.result;
    }

    /// Check if the operation succeeded.
    pub fn succeeded(self: *const ConnectEvent) bool {
        return self.raw.result == 0;
    }
};

// =============================================================================
// AcceptEvent - Event for on_net_accept
// =============================================================================

/// Event passed to on_net_accept callback.
/// Inbound connection accepted on a listening socket.
pub const AcceptEvent = struct {
    raw: *ffi.c.qcontrol_net_accept_event_t,

    /// Get the accepted socket file descriptor.
    pub fn fd(self: *const AcceptEvent) i32 {
        return self.raw.fd;
    }

    /// Get the listening socket file descriptor.
    pub fn listenFd(self: *const AcceptEvent) i32 {
        return self.raw.listen_fd;
    }

    /// Get the remote client address.
    pub fn srcAddr(self: *const AcceptEvent) []const u8 {
        if (self.raw.src_addr) |a| {
            return a[0..self.raw.src_addr_len];
        }
        return "";
    }

    /// Get the remote client port.
    pub fn srcPort(self: *const AcceptEvent) u16 {
        return self.raw.src_port;
    }

    /// Get the local server address.
    pub fn dstAddr(self: *const AcceptEvent) []const u8 {
        if (self.raw.dst_addr) |a| {
            return a[0..self.raw.dst_addr_len];
        }
        return "";
    }

    /// Get the local server port.
    pub fn dstPort(self: *const AcceptEvent) u16 {
        return self.raw.dst_port;
    }

    /// Get the result (fd on success, -errno on failure).
    pub fn result(self: *const AcceptEvent) i32 {
        return self.raw.result;
    }

    /// Check if the operation succeeded.
    pub fn succeeded(self: *const AcceptEvent) bool {
        return self.raw.result >= 0;
    }
};

// =============================================================================
// TlsEvent - Event for on_net_tls
// =============================================================================

/// Event passed to on_net_tls callback.
/// TLS handshake completed on a connection.
pub const TlsEvent = struct {
    raw: *ffi.c.qcontrol_net_tls_event_t,

    /// Get the socket file descriptor.
    pub fn fd(self: *const TlsEvent) i32 {
        return self.raw.fd;
    }

    /// Get the TLS version string (e.g., "TLSv1.2", "TLSv1.3").
    pub fn version(self: *const TlsEvent) []const u8 {
        if (self.raw.version) |v| {
            return v[0..self.raw.version_len];
        }
        return "";
    }

    /// Get the cipher suite (may be empty).
    pub fn cipher(self: *const TlsEvent) ?[]const u8 {
        if (self.raw.cipher) |c| {
            if (self.raw.cipher_len > 0) {
                return c[0..self.raw.cipher_len];
            }
        }
        return null;
    }
};

// =============================================================================
// DomainEvent - Event for on_net_domain
// =============================================================================

/// Event passed to on_net_domain callback.
/// Domain name discovered (from SNI, Host header, etc.)
pub const DomainEvent = struct {
    raw: *ffi.c.qcontrol_net_domain_event_t,

    /// Get the socket file descriptor.
    pub fn fd(self: *const DomainEvent) i32 {
        return self.raw.fd;
    }

    /// Get the domain name.
    pub fn domain(self: *const DomainEvent) []const u8 {
        if (self.raw.domain) |d| {
            return d[0..self.raw.domain_len];
        }
        return "";
    }
};

// =============================================================================
// ProtocolEvent - Event for on_net_protocol
// =============================================================================

/// Event passed to on_net_protocol callback.
/// Application protocol detected (from ALPN, content sniffing, etc.)
pub const ProtocolEvent = struct {
    raw: *ffi.c.qcontrol_net_protocol_event_t,

    /// Get the socket file descriptor.
    pub fn fd(self: *const ProtocolEvent) i32 {
        return self.raw.fd;
    }

    /// Get the protocol identifier (e.g., "http/1.1", "h2").
    pub fn protocol(self: *const ProtocolEvent) []const u8 {
        if (self.raw.protocol) |p| {
            return p[0..self.raw.protocol_len];
        }
        return "";
    }
};

// =============================================================================
// SendEvent - Event for on_net_send
// =============================================================================

/// Event passed to on_net_send callback.
/// Data being sent on a connection.
pub const SendEvent = struct {
    raw: *ffi.c.qcontrol_net_send_event_t,

    /// Get the socket file descriptor.
    pub fn fd(self: *const SendEvent) i32 {
        return self.raw.fd;
    }

    /// Get the data being sent.
    pub fn data(self: *const SendEvent) []const u8 {
        const ptr: [*]const u8 = @ptrCast(self.raw.buf orelse return &.{});
        return ptr[0..self.raw.count];
    }

    /// Get the byte count.
    pub fn count(self: *const SendEvent) usize {
        return self.raw.count;
    }
};

// =============================================================================
// RecvEvent - Event for on_net_recv
// =============================================================================

/// Event passed to on_net_recv callback.
/// Data received on a connection.
pub const RecvEvent = struct {
    raw: *ffi.c.qcontrol_net_recv_event_t,

    /// Get the socket file descriptor.
    pub fn fd(self: *const RecvEvent) i32 {
        return self.raw.fd;
    }

    /// Get the data received. Only valid if result > 0.
    pub fn data(self: *const RecvEvent) ?[]const u8 {
        if (self.raw.result > 0) {
            const ptr: [*]const u8 = @ptrCast(self.raw.buf orelse return null);
            return ptr[0..@intCast(self.raw.result)];
        }
        return null;
    }

    /// Get the requested byte count.
    pub fn count(self: *const RecvEvent) usize {
        return self.raw.count;
    }

    /// Get the result (bytes received or -errno on error).
    pub fn result(self: *const RecvEvent) isize {
        return self.raw.result;
    }
};

// =============================================================================
// CloseEvent - Event for on_net_close
// =============================================================================

/// Event passed to on_net_close callback.
/// Connection closed.
pub const CloseEvent = struct {
    raw: *ffi.c.qcontrol_net_close_event_t,

    /// Get the socket file descriptor.
    pub fn fd(self: *const CloseEvent) i32 {
        return self.raw.fd;
    }

    /// Get the result (0 on success, -errno on failure).
    pub fn result(self: *const CloseEvent) i32 {
        return self.raw.result;
    }
};
