const std = @import("std");

const c_flags = [_][]const u8{ "-std=c99", "-ffp-contract=off", "-fno-sanitize=undefined", "-fno-strict-aliasing" };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("goome", .{
        .root_source_file = b.path("src/goome.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .sanitize_c = .off,
    });
    mod.addIncludePath(b.path("native"));
    mod.addCSourceFile(.{ .file = b.path("native/goome_lib.c"), .flags = &c_flags });

    const c_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .sanitize_c = .off,
    });
    c_mod.addCSourceFile(.{ .file = b.path("native/goome_lib.c"), .flags = &c_flags });
    const lib = b.addLibrary(.{ .name = "goome", .linkage = .static, .root_module = c_mod });
    lib.installHeader(b.path("native/goome.h"), "goome.h");
    b.installArtifact(lib);

    const layout_mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    layout_mod.addIncludePath(b.path("native"));
    layout_mod.addCSourceFile(.{ .file = b.path("tests/layout.c"), .flags = &.{"-std=c99"} });
    const layout = b.addExecutable(.{ .name = "layout", .root_module = layout_mod });
    const layout_run = b.addRunArtifact(layout);
    const layout_out = layout_run.captureStdOut();

    const test_mod = b.createModule(.{
        .root_source_file = b.path("tests/goome_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_mod.addImport("goome", mod);
    test_mod.addAnonymousImport("layout.txt", .{ .root_source_file = layout_out });
    const tests = b.addTest(.{ .root_module = test_mod });
    const tests_run = b.addRunArtifact(tests);
    const test_step = b.step("test", "run the tests on the test backend");
    test_step.dependOn(&tests_run.step);

    const examples_step = b.step("examples", "build the examples");
    inline for (.{ "hello", "grab", "ui_demo" }) |name| {
        const ex_mod = b.createModule(.{
            .root_source_file = b.path("examples/" ++ name ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });
        ex_mod.addImport("goome", mod);
        const exe = b.addExecutable(.{ .name = name, .root_module = ex_mod });
        const install = b.addInstallArtifact(exe, .{});
        examples_step.dependOn(&install.step);
        const run = b.addRunArtifact(exe);
        if (b.args) |args| run.addArgs(args);
        const run_step = b.step("run-" ++ name, "run examples/" ++ name ++ ".zig");
        run_step.dependOn(&run.step);
    }
}
