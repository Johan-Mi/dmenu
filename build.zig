const std = @import("std");

const version = "\"4.9.0\"";

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const xinerama = b.option(bool, "xinerama", "compile with Xinerama support") orelse true;

    const dmenu_exe = b.addExecutable(.{
        .name = "dmenu",
        .target = target,
        .optimize = optimize,
    });
    dmenu_exe.addCSourceFiles(.{ .files = &[_][]const u8{
        "src/dmenu.c",
        "src/drw.c",
        "src/util.c",
    } });
    dmenu_exe.defineCMacro("VERSION", version);
    dmenu_exe.linkLibC();
    dmenu_exe.linkSystemLibrary("fontconfig");
    dmenu_exe.linkSystemLibrary("Xft");
    dmenu_exe.linkSystemLibrary("X11");
    if (xinerama) {
        dmenu_exe.defineCMacro("XINERAMA", "");
        dmenu_exe.linkSystemLibrary("Xinerama");
    }

    const stest_exe = b.addExecutable(.{
        .name = "stest",
        .root_source_file = b.path("src/stest.zig"),
        .target = target,
        .optimize = optimize,
    });
    stest_exe.linkLibC();

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(dmenu_exe);
    b.installArtifact(stest_exe);

    b.installFile("dmenu.1", "share/man/man1/dmenu.1");
    b.installFile("stest.1", "share/man/man1/stest.1");
    b.installBinFile("dmenu_path", "dmenu_path");
    b.installBinFile("dmenu_run", "dmenu_run");

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(dmenu_exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
