const std = @import("std");

const pieces = [_]struct { name: []const u8, src: []const u8 }{
    .{ .name = "dots", .src = "src/dots.zig" },
    .{ .name = "intersectingLines", .src = "src/intersectingLines.zig" },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{ .target = target, .optimize = optimize });
    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const zart = b.createModule(.{
        .root_source_file = b.path("src/zart.zig"),
        .target = target,
        .optimize = optimize,
    });
    zart.addImport("raylib", raylib);

    for (pieces) |piece| {
        const exe = b.addExecutable(.{
            .name = piece.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(piece.src),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.linkLibrary(raylib_artifact);
        exe.root_module.addImport("raylib", raylib);
        exe.root_module.addImport("zart", zart);
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_cmd.addArgs(args);

        const run_step = b.step(b.fmt("run-{s}", .{piece.name}), b.fmt("Run {s}", .{piece.name}));
        run_step.dependOn(&run_cmd.step);
    }
}
