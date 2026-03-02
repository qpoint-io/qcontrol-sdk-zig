const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Auto-detect local SDK (for development in monorepo)
    // Falls back to fetching from build.zig.zon dependency for CI/releases
    const local_sdk_path = b.path("../../build.zig").getPath(b);
    const use_local_sdk = std.fs.cwd().access(local_sdk_path, .{}) != error.FileNotFound;

    if (use_local_sdk) {
        std.log.info("Using local SDK at ../..", .{});
    }

    const qcontrol_mod = if (use_local_sdk)
        createLocalSdkModule(b, target, optimize)
    else
        b.dependency("qcontrol", .{ .target = target, .optimize = optimize }).module("qcontrol");

    // Text transform plugin - shared library
    const text_transform = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "text_transform",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    text_transform.root_module.addImport("qcontrol", qcontrol_mod);
    b.installArtifact(text_transform);

    // Text transform plugin - object file for bundling
    const text_transform_obj = b.addObject(.{
        .name = "text_transform",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .pic = true,
        }),
    });
    text_transform_obj.root_module.addImport("qcontrol", qcontrol_mod);
    const install_obj = b.addInstallFile(text_transform_obj.getEmittedBin(), "lib/text_transform.o");
    b.getInstallStep().dependOn(&install_obj.step);
}

// Create qcontrol module from local SDK (mirrors sdk/zig/build.zig)
fn createLocalSdkModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const mod = b.createModule(.{
        .root_source_file = b.path("../../src/qcontrol.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(b.path("../../include"));
    return mod;
}
