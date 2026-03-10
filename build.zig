const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the qcontrol module with C headers pre-configured
    const qcontrol_mod = b.addModule("qcontrol", .{
        .root_source_file = b.path("src/qcontrol.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true, // Required for @cImport of C SDK headers
    });

    // Add bundled C headers for type imports
    qcontrol_mod.addIncludePath(b.path("include"));

}
