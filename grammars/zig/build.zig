const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const treesitter_mod = b.createModule(.{
        .root_source_file = b.path("../../src/treesitter.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("tree_sitter_zig", .{
        .root_source_file = b.path("src/parser.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("treesitter", treesitter_mod);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("examples/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("treesitter", treesitter_mod);
    exe_mod.addImport("tree_sitter_zig", mod);

    const example = b.addExecutable(.{
        .name = "zig_example",
        .root_module = exe_mod,
    });

    const run_cmd = b.addRunArtifact(example);
    const run_step = b.step("run", "Run zig example");
    run_step.dependOn(&run_cmd.step);

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/parser.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("treesitter", treesitter_mod);

    const tests = b.addTest(.{
        .root_module = test_mod,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
