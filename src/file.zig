//! File operation contexts.
//!
//! These types wrap the raw C context structs and provide idiomatic Zig accessors.

const std = @import("std");
const ffi = @import("ffi.zig");
const types = @import("types.zig");

pub const Phase = types.Phase;

/// Context for open() operations.
pub const FileOpenContext = struct {
    raw: *ffi.RawFileOpenCtx,

    /// Get the operation phase.
    pub fn phase(self: FileOpenContext) Phase {
        return if (self.raw.phase == 0) .enter else .leave;
    }

    /// Get the file path being opened.
    pub fn path(self: FileOpenContext) []const u8 {
        return std.mem.span(self.raw.path);
    }

    /// Get the open flags.
    pub fn flags(self: FileOpenContext) i32 {
        return self.raw.flags;
    }

    /// Get the file mode (for O_CREAT).
    pub fn mode(self: FileOpenContext) u32 {
        return self.raw.mode;
    }

    /// Get the result fd (or negative errno). Only valid in leave phase.
    pub fn result(self: FileOpenContext) i32 {
        return self.raw.result;
    }

    /// Check if the operation succeeded.
    pub fn succeeded(self: FileOpenContext) bool {
        return self.raw.result >= 0;
    }

    /// Set a modified path. Only effective in enter phase with FilterResult.modify.
    pub fn setPath(self: FileOpenContext, new_path: []const u8) void {
        const len = @min(new_path.len, ffi.MAX_PATH - 1);
        @memcpy(self.raw.path_out[0..len], new_path[0..len]);
        self.raw.path_out[len] = 0;
    }
};

/// Context for read() operations.
pub const FileReadContext = struct {
    raw: *ffi.RawFileReadCtx,

    pub fn phase(self: FileReadContext) Phase {
        return if (self.raw.phase == 0) .enter else .leave;
    }

    /// Get the file descriptor.
    pub fn fd(self: FileReadContext) i32 {
        return self.raw.fd;
    }

    /// Get the requested byte count.
    pub fn count(self: FileReadContext) usize {
        return self.raw.count;
    }

    /// Get the result (bytes read or negative errno). Only valid in leave phase.
    pub fn result(self: FileReadContext) isize {
        return self.raw.result;
    }

    /// Get the buffer contents. Only valid in leave phase after successful read.
    pub fn buffer(self: FileReadContext) ?[]const u8 {
        if (self.raw.result > 0) {
            const ptr: [*]const u8 = @ptrCast(self.raw.buf orelse return null);
            return ptr[0..@intCast(self.raw.result)];
        }
        return null;
    }
};

/// Context for write() operations.
pub const FileWriteContext = struct {
    raw: *ffi.RawFileWriteCtx,

    pub fn phase(self: FileWriteContext) Phase {
        return if (self.raw.phase == 0) .enter else .leave;
    }

    /// Get the file descriptor.
    pub fn fd(self: FileWriteContext) i32 {
        return self.raw.fd;
    }

    /// Get the byte count.
    pub fn count(self: FileWriteContext) usize {
        return self.raw.count;
    }

    /// Get the result (bytes written or negative errno). Only valid in leave phase.
    pub fn result(self: FileWriteContext) isize {
        return self.raw.result;
    }

    /// Get the buffer being written.
    pub fn buffer(self: FileWriteContext) []const u8 {
        const ptr: [*]const u8 = @ptrCast(self.raw.buf orelse return &.{});
        return ptr[0..self.raw.count];
    }
};

/// Context for close() operations.
pub const FileCloseContext = struct {
    raw: *ffi.RawFileCloseCtx,

    pub fn phase(self: FileCloseContext) Phase {
        return if (self.raw.phase == 0) .enter else .leave;
    }

    /// Get the file descriptor.
    pub fn fd(self: FileCloseContext) i32 {
        return self.raw.fd;
    }

    /// Get the result (0 or negative errno). Only valid in leave phase.
    pub fn result(self: FileCloseContext) i32 {
        return self.raw.result;
    }
};
