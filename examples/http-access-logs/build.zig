const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const local_sdk_path = b.path("../../build.zig").getPath(b);
    const use_local_sdk = std.fs.cwd().access(local_sdk_path, .{}) != error.FileNotFound;

    if (use_local_sdk) {
        std.log.info("Using local SDK at ../..", .{});
    }

    const qcontrol_mod = if (use_local_sdk)
        createLocalSdkModule(b, target, optimize)
    else
        b.dependency("qcontrol", .{ .target = target, .optimize = optimize }).module("qcontrol");

    const http_access_logs = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "http_access_logs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    http_access_logs.root_module.addImport("qcontrol", qcontrol_mod);
    b.installArtifact(http_access_logs);

    const http_access_logs_obj = b.addObject(.{
        .name = "http_access_logs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .pic = true,
        }),
    });
    http_access_logs_obj.root_module.addImport("qcontrol", qcontrol_mod);
    const install_obj = b.addInstallFile(http_access_logs_obj.getEmittedBin(), "lib/http_access_logs.o");
    b.getInstallStep().dependOn(&install_obj.step);
}

fn createLocalSdkModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const mod = b.createModule(.{
        .root_source_file = b.path("../../src/qcontrol.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(b.path("../../include"));
    return mod;
}
