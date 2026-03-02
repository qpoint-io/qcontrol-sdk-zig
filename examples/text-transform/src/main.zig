//! Text transform plugin - demonstrates custom buffer manipulation
//!
//! Uses RwConfig.transform for advanced buffer operations.
//! Applies different transforms based on file extension:
//!   .upper    - Convert text to uppercase
//!   .rot13    - Apply ROT13 encoding
//!   .bracket  - Wrap content in brackets
//!
//! Environment variables:
//!   QCONTROL_LOG_FILE - Path to log file (default: /tmp/qcontrol.log)

const std = @import("std");
const qcontrol = @import("qcontrol");

/// Transform mode for the file.
const TransformMode = enum {
    upper,
    rot13,
    bracket,
};

/// Per-file state tracking transform mode.
const TransformState = struct {
    path: []u8,
    mode: TransformMode,
    allocator: std.mem.Allocator,

    fn create(allocator: std.mem.Allocator, path: []const u8, mode: TransformMode) !*TransformState {
        const state = try allocator.create(TransformState);
        state.* = .{
            .path = try allocator.dupe(u8, path),
            .mode = mode,
            .allocator = allocator,
        };
        return state;
    }

    fn destroy(self: *TransformState) void {
        self.allocator.free(self.path);
        self.allocator.destroy(self);
    }
};

var logger: qcontrol.Logger = .{};

/// Custom transform function - modifies buffer based on transform mode.
fn readTransform(state_ptr: ?*anyopaque, ctx: *qcontrol.file.Ctx, buf: *qcontrol.file.Buffer) qcontrol.file.Action {
    _ = ctx;

    const state: *TransformState = @ptrCast(@alignCast(state_ptr orelse return .pass));

    // Get the current buffer contents
    const data = buf.slice();
    if (data.len == 0) return .pass;

    switch (state.mode) {
        .upper => {
            // Convert to uppercase using buffer operations
            // We'll do this by replacing lowercase letters
            var i: usize = 0;
            while (i < data.len) : (i += 1) {
                const c = data[i];
                if (c >= 'a' and c <= 'z') {
                    // Replace single character using replaceAll (inefficient but demonstrates API)
                    const lower = [1]u8{c};
                    const upper = [1]u8{c - 32};
                    _ = buf.replace(&lower, &upper);
                }
            }
        },
        .rot13 => {
            // ROT13: rotate letters by 13 positions
            // Create a transformed copy and set the buffer
            var transformed: [4096]u8 = undefined;
            const len = @min(data.len, transformed.len);

            for (data[0..len], 0..) |c, i| {
                transformed[i] = if (c >= 'a' and c <= 'z')
                    'a' + @as(u8, @intCast((@as(u16, c - 'a') + 13) % 26))
                else if (c >= 'A' and c <= 'Z')
                    'A' + @as(u8, @intCast((@as(u16, c - 'A') + 13) % 26))
                else
                    c;
            }

            buf.set(transformed[0..len]);
        },
        .bracket => {
            // Wrap content in brackets
            buf.prepend("[[[ ");
            buf.append(" ]]]");
        },
    }

    return .pass;
}

fn onFileOpen(ev: *qcontrol.file.OpenEvent) qcontrol.file.OpenResult {
    if (!ev.succeeded()) return .pass;

    const path = ev.path();

    // Determine transform mode based on extension
    const mode: ?TransformMode = if (std.mem.endsWith(u8, path, ".upper"))
        .upper
    else if (std.mem.endsWith(u8, path, ".rot13"))
        .rot13
    else if (std.mem.endsWith(u8, path, ".bracket"))
        .bracket
    else
        null;

    if (mode) |m| {
        const state = TransformState.create(std.heap.c_allocator, path, m) catch return .pass;
        logger.print("[text_transform] filtering {s} with mode {s}", .{ path, @tagName(m) });

        return .{ .session = .{
            .state = state,
            .file_read = .{
                .transform = readTransform,
            },
        } };
    }

    return .pass;
}

fn onFileClose(state: ?*anyopaque, ev: *qcontrol.file.CloseEvent) void {
    _ = ev;
    if (state) |s| {
        const transform_state: *TransformState = @ptrCast(@alignCast(s));
        logger.print("[text_transform] closed: {s}", .{transform_state.path});
        transform_state.destroy();
    }
}

fn init() void {
    logger.init();
    logger.print("[text_transform] initializing...", .{});
}

fn cleanup() void {
    logger.print("[text_transform] cleanup complete", .{});
    logger.deinit();
}

comptime {
    qcontrol.exportPlugin(.{
        .name = "zig_text_transform",
        .on_init = init,
        .on_cleanup = cleanup,
        .on_file_open = onFileOpen,
        .on_file_close = onFileClose,
        // Note: on_file_read/on_file_write not needed - the custom transform
        // function is called automatically via the session config
    });
}
