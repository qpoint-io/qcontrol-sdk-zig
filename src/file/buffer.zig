//! Opaque Buffer type for transform functions.
//!
//! Wraps the agent's C buffer operations. Plugins use this to inspect
//! and modify data during read/write transforms.

const std = @import("std");
const ffi = @import("../ffi.zig");

/// Opaque buffer type wrapping the agent's buffer operations.
pub const Buffer = struct {
    raw: *ffi.c.qcontrol_buffer_t,

    // =========================================================================
    // Read Operations
    // =========================================================================

    /// Get a read-only slice of the buffer contents.
    pub fn slice(self: *const Buffer) []const u8 {
        const data = ffi.c.qcontrol_buffer_data(self.raw);
        const length = ffi.c.qcontrol_buffer_len(self.raw);
        if (data) |ptr| {
            return ptr[0..length];
        }
        return "";
    }

    /// Get the buffer length.
    pub fn len(self: *const Buffer) usize {
        return ffi.c.qcontrol_buffer_len(self.raw);
    }

    /// Check if the buffer contains the needle.
    pub fn contains(self: *const Buffer, needle: []const u8) bool {
        return ffi.c.qcontrol_buffer_contains(self.raw, needle.ptr, needle.len) != 0;
    }

    /// Check if the buffer starts with the prefix.
    pub fn startsWith(self: *const Buffer, prefix: []const u8) bool {
        return ffi.c.qcontrol_buffer_starts_with(self.raw, prefix.ptr, prefix.len) != 0;
    }

    /// Check if the buffer ends with the suffix.
    pub fn endsWith(self: *const Buffer, suffix: []const u8) bool {
        return ffi.c.qcontrol_buffer_ends_with(self.raw, suffix.ptr, suffix.len) != 0;
    }

    /// Find the index of needle in the buffer.
    /// Returns null if not found.
    pub fn indexOf(self: *const Buffer, needle: []const u8) ?usize {
        const result = ffi.c.qcontrol_buffer_index_of(self.raw, needle.ptr, needle.len);
        if (result == std.math.maxInt(usize)) return null;
        return result;
    }

    // =========================================================================
    // Write Operations
    // =========================================================================

    /// Prepend data to the beginning of the buffer.
    pub fn prepend(self: *Buffer, data: []const u8) void {
        ffi.c.qcontrol_buffer_prepend(self.raw, data.ptr, data.len);
    }

    /// Append data to the end of the buffer.
    pub fn append(self: *Buffer, data: []const u8) void {
        ffi.c.qcontrol_buffer_append(self.raw, data.ptr, data.len);
    }

    /// Replace the first occurrence of needle with replacement.
    /// Returns true if a replacement was made.
    pub fn replace(self: *Buffer, needle: []const u8, replacement: []const u8) bool {
        return ffi.c.qcontrol_buffer_replace(
            self.raw,
            needle.ptr,
            needle.len,
            replacement.ptr,
            replacement.len,
        ) != 0;
    }

    /// Replace all occurrences of needle with replacement.
    /// Returns the number of replacements made.
    pub fn replaceAll(self: *Buffer, needle: []const u8, replacement: []const u8) usize {
        return ffi.c.qcontrol_buffer_replace_all(
            self.raw,
            needle.ptr,
            needle.len,
            replacement.ptr,
            replacement.len,
        );
    }

    /// Remove the first occurrence of needle.
    /// Returns true if a removal was made.
    pub fn remove(self: *Buffer, needle: []const u8) bool {
        return ffi.c.qcontrol_buffer_remove(self.raw, needle.ptr, needle.len) != 0;
    }

    /// Remove all occurrences of needle.
    /// Returns the number of removals.
    pub fn removeAll(self: *Buffer, needle: []const u8) usize {
        return ffi.c.qcontrol_buffer_remove_all(self.raw, needle.ptr, needle.len);
    }

    /// Clear the buffer contents.
    pub fn clear(self: *Buffer) void {
        ffi.c.qcontrol_buffer_clear(self.raw);
    }

    /// Set the buffer contents to the given data.
    pub fn set(self: *Buffer, data: []const u8) void {
        ffi.c.qcontrol_buffer_set(self.raw, data.ptr, data.len);
    }

    /// Insert data at the given position.
    pub fn insertAt(self: *Buffer, pos: usize, data: []const u8) void {
        ffi.c.qcontrol_buffer_insert_at(self.raw, pos, data.ptr, data.len);
    }

    /// Remove a range of bytes from the buffer.
    pub fn removeRange(self: *Buffer, start: usize, end: usize) void {
        ffi.c.qcontrol_buffer_remove_range(self.raw, start, end);
    }
};
