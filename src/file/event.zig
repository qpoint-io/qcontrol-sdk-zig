//! File event types wrapping C event structs.
//!
//! These provide idiomatic Zig accessors for the raw C event data.

const std = @import("std");
const ffi = @import("../ffi.zig");

// =============================================================================
// OpenEvent - Event for on_file_open
// =============================================================================

/// Event passed to on_file_open callback.
pub const OpenEvent = struct {
    raw: *ffi.c.qcontrol_file_open_event_t,

    /// Get the file path being opened.
    pub fn path(self: *const OpenEvent) []const u8 {
        if (self.raw.path) |p| {
            return p[0..self.raw.path_len];
        }
        return "";
    }

    /// Get the open flags (O_RDONLY, O_WRONLY, etc.).
    pub fn flags(self: *const OpenEvent) i32 {
        return self.raw.flags;
    }

    /// Get the file mode (for O_CREAT).
    pub fn mode(self: *const OpenEvent) u32 {
        return self.raw.mode;
    }

    /// Get the result fd on success, or negative errno on failure.
    pub fn result(self: *const OpenEvent) i32 {
        return self.raw.result;
    }

    /// Check if the operation succeeded.
    pub fn succeeded(self: *const OpenEvent) bool {
        return self.raw.result >= 0;
    }
};

// =============================================================================
// ReadEvent - Event for on_file_read
// =============================================================================

/// Event passed to on_file_read callback.
pub const ReadEvent = struct {
    raw: *ffi.c.qcontrol_file_read_event_t,

    /// Get the file descriptor.
    pub fn fd(self: *const ReadEvent) i32 {
        return self.raw.fd;
    }

    /// Get the requested byte count.
    pub fn count(self: *const ReadEvent) usize {
        return self.raw.count;
    }

    /// Get the result (bytes read or negative errno).
    pub fn result(self: *const ReadEvent) isize {
        return self.raw.result;
    }

    /// Get the data that was read. Only valid if result > 0.
    pub fn data(self: *const ReadEvent) ?[]const u8 {
        if (self.raw.result > 0) {
            const ptr: [*]const u8 = @ptrCast(self.raw.buf orelse return null);
            return ptr[0..@intCast(self.raw.result)];
        }
        return null;
    }
};

// =============================================================================
// WriteEvent - Event for on_file_write
// =============================================================================

/// Event passed to on_file_write callback.
pub const WriteEvent = struct {
    raw: *ffi.c.qcontrol_file_write_event_t,

    /// Get the file descriptor.
    pub fn fd(self: *const WriteEvent) i32 {
        return self.raw.fd;
    }

    /// Get the byte count to write.
    pub fn count(self: *const WriteEvent) usize {
        return self.raw.count;
    }

    /// Get the result (bytes written or negative errno).
    pub fn result(self: *const WriteEvent) isize {
        return self.raw.result;
    }

    /// Get the data being written.
    pub fn data(self: *const WriteEvent) []const u8 {
        const ptr: [*]const u8 = @ptrCast(self.raw.buf orelse return &.{});
        return ptr[0..self.raw.count];
    }
};

// =============================================================================
// CloseEvent - Event for on_file_close
// =============================================================================

/// Event passed to on_file_close callback.
pub const CloseEvent = struct {
    raw: *ffi.c.qcontrol_file_close_event_t,

    /// Get the file descriptor.
    pub fn fd(self: *const CloseEvent) i32 {
        return self.raw.fd;
    }

    /// Get the result (0 or negative errno).
    pub fn result(self: *const CloseEvent) i32 {
        return self.raw.result;
    }
};
