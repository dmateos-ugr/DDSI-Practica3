const std = @import("std");
const builtin = @import("builtin");
const build_zdb = @import("zdb/build_pkg.zig");
const Pkg = std.build.Pkg;

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    // Build exe
    const exe = b.addExecutable("spotycloud", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    // ZDB
    build_zdb.buildPkg(exe, "zdb");

    // Run exe
    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Format step
    const fmt_step = b.addFmt(&.{"src"});
    exe.step.dependOn(&fmt_step.step);
}
