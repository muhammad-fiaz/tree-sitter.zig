const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const treesitter_mod = b.createModule(.{
        .root_source_file = b.path("../../src/treesitter.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("tree_sitter_c", .{
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
    exe_mod.addImport("tree_sitter_c", mod);

    const example = b.addExecutable(.{
        .name = "c_example",
        .root_module = exe_mod,
    });

    const run_cmd = b.addRunArtifact(example);
    const run_step = b.step("run", "Run c example");
    run_step.dependOn(&run_cmd.step);

    const extra_examples = [_][]const u8{ "cluster", "malloc", "parser" };
    inline for (extra_examples) |ex_name| {
        const em = b.createModule(.{
            .root_source_file = b.path(b.fmt("examples/{s}.zig", .{ex_name})),
            .target = target,
            .optimize = optimize,
        });
        em.addImport("treesitter", treesitter_mod);
        em.addImport("tree_sitter_c", mod);
        const e_exe = b.addExecutable(.{
            .name = b.fmt("c_{s}_example", .{ex_name}),
            .root_module = em,
        });
        const e_run = b.addRunArtifact(e_exe);
        const e_step = b.step(b.fmt("run-{s}", .{ex_name}), b.fmt("Run C {s} example", .{ex_name}));
        e_step.dependOn(&e_run.step);
    }

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
