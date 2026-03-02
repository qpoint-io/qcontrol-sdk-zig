//! Pattern replacement helpers.
//!
//! Provides ergonomic syntax for defining string replacement patterns.

const ffi = @import("../ffi.zig");

/// A single pattern for string replacement.
pub const Pattern = struct {
    needle: []const u8,
    replacement: []const u8,

    /// Convert to C ABI struct.
    pub fn toC(self: Pattern) ffi.c.qcontrol_file_pattern_t {
        return .{
            .needle = self.needle.ptr,
            .needle_len = self.needle.len,
            .replacement = self.replacement.ptr,
            .replacement_len = self.replacement.len,
        };
    }
};

/// Helper to create a slice of patterns from tuples.
///
/// Example:
/// ```zig
/// const pats = patterns(&.{
///     .{ "password", "****" },
///     .{ "secret", "[REDACTED]" },
/// });
/// ```
pub fn patterns(comptime tuples: anytype) []const Pattern {
    const fields = @typeInfo(@TypeOf(tuples.*)).@"struct".fields;
    const result = comptime blk: {
        var arr: [fields.len]Pattern = undefined;
        for (fields, 0..) |field, i| {
            const tuple = @field(tuples.*, field.name);
            arr[i] = .{
                .needle = tuple[0],
                .replacement = tuple[1],
            };
        }
        break :blk arr;
    };
    return &result;
}
