const std = @import("std");
const rl = @import("raylib-zig/build.zig");

const debugTerrain = "src/debug_terrain.zig";
const mainGame = "src/main.zig";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const raylib = rl.getModule(b, "raylib-zig");
    const raylib_math = rl.math.getModule(b, "raylib-zig");
    //web exports are completely separate
    if (target.getOsTag() == .emscripten) {
        const exe_lib = rl.compileForEmscripten(b, "wastelands", "src/main.zig", target, optimize);
        exe_lib.addModule("raylib", raylib);
        exe_lib.addModule("raylib-math", raylib_math);
        const raylib_artifact = rl.getRaylib(b, target, optimize);
        // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
        exe_lib.linkLibrary(raylib_artifact);
        const link_step = try rl.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });
        b.getInstallStep().dependOn(&link_step.step);
        const run_step = try rl.emscriptenRunStep(b);
        run_step.step.dependOn(&link_step.step);
        const run_option = b.step("run", "Run wastelands");
        run_option.dependOn(&run_step.step);
        return;
    }

    const exe = b.addExecutable(.{ .name = "wastelands", .root_source_file = .{ .path = debugTerrain }, .optimize = optimize, .target = target });

    rl.link(b, exe, target, optimize);
    exe.addModule("raylib", raylib);
    exe.addModule("raylib-math", raylib_math);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run wastelands");
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(exe);
}
