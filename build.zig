// build.zig
const std = @import("std");
const raySdk = @import("libs/raylib/src/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dungeon-zig",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const dungen = b.addModule("dungen", .{ .source_file = .{ .path = "src/dungen.zig" } });
    exe.addModule("dungen", dungen);

    b.installArtifact(exe);

    var raylib = raySdk.addRaylib(b, target, optimize, .{});
    exe.addIncludePath(.{ .path = "libs/raylib/src" });
    exe.linkLibrary(raylib);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
