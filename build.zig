const std = @import("std");
const builtin = @import("builtin");

/// Build configuration for tree-sitter.zig - a native Zig implementation of
/// the Tree-sitter runtime. Zig 0.16.0 only, standard library only.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("treesitter", .{
        .root_source_file = b.path("src/treesitter.zig"),
        .target = target,
        .optimize = optimize,
    });

    // All tests live inline at the bottom of the source files that
    // implement the functionality (see src/*/); the unit run below
    // executes every one of them. The differential conformance corpus
    // (src/debug/corpus) runs as part of the suite plus separately via
    // `zig build conformance`.
    const test_step = b.step("test", "Run all unit and integration tests");

    const unit_mod = b.createModule(.{
        .root_source_file = b.path("src/treesitter.zig"),
        .target = target,
        .optimize = optimize,
    });
    const unit_tests = b.addTest(.{ .root_module = unit_mod });
    const run_unit = b.addRunArtifact(unit_tests);
    run_unit.has_side_effects = true;

    // Only run tests when target matches host; otherwise build test artifacts only.
    const run_tests_on_host = target.result.os.tag == builtin.os.tag and
        target.result.cpu.arch == builtin.cpu.arch;

    if (run_tests_on_host) {
        test_step.dependOn(&run_unit.step);
    } else {
        const install_unit = b.addInstallArtifact(unit_tests, .{});
        test_step.dependOn(&install_unit.step);
    }

    const examples: []const []const u8 = &.{
        "basic_parse",
        "incremental_parse",
        "tree_walk",
        "tree_cursor",
        "query",
        "query_directives",
        "custom_input",
        "utf16_parse",
        "error_recovery",
        "language",
        "sexp_parse",
        "json_parse",
        "external_scanner",
    };
    const examples_step = b.step("examples", "Build all examples");
    const run_all_examples = b.step("run-all-examples", "Run all examples sequentially");
    var previous_run_step: ?*std.Build.Step = null;
    for (examples) |name| {
        const m = b.createModule(.{
            .root_source_file = b.path(b.fmt("examples/{s}.zig", .{name})),
            .target = target,
            .optimize = optimize,
        });
        m.addImport("treesitter", mod);
        const exe = b.addExecutable(.{ .name = name, .root_module = m });
        const install_exe = b.addInstallArtifact(exe, .{});
        b.installArtifact(exe);
        examples_step.dependOn(&install_exe.step);

        const run_exe = b.addRunArtifact(exe);
        run_exe.step.dependOn(&install_exe.step);
        if (previous_run_step) |prev| run_exe.step.dependOn(prev);
        const run_step = b.step(b.fmt("run-{s}", .{name}), b.fmt("Run {s} example", .{name}));
        run_step.dependOn(&run_exe.step);
        previous_run_step = &run_exe.step;
    }
    if (previous_run_step) |last| run_all_examples.dependOn(last);

    const bench_step = b.step("bench", "Run benchmarks");
    const bench_mod = b.createModule(.{
        .root_source_file = b.path("benchmarks/parse_bench.zig"),
        .target = target,
        .optimize = optimize,
    });
    bench_mod.addImport("treesitter", mod);
    const bench_exe = b.addExecutable(.{ .name = "parse_bench", .root_module = bench_mod });
    const install_bench = b.addInstallArtifact(bench_exe, .{});
    const run_bench = b.addRunArtifact(bench_exe);
    run_bench.step.dependOn(&install_bench.step);
    bench_step.dependOn(&run_bench.step);

    const fuzz_step = b.step("fuzz", "Run the parser/query fuzzer (pass --iterations=N --seed=N after --)");
    const fuzz_mod = b.createModule(.{
        .root_source_file = b.path("fuzz/fuzz.zig"),
        .target = target,
        .optimize = optimize,
    });
    fuzz_mod.addImport("treesitter", mod);
    const fuzz_exe = b.addExecutable(.{ .name = "fuzz", .root_module = fuzz_mod });
    const install_fuzz = b.addInstallArtifact(fuzz_exe, .{});
    const run_fuzz = b.addRunArtifact(fuzz_exe);
    if (b.args) |args| run_fuzz.addArgs(args);
    run_fuzz.step.dependOn(&install_fuzz.step);
    fuzz_step.dependOn(&run_fuzz.step);

    const conformance_step = b.step("conformance", "Run the differential conformance corpus");
    const conformance_mod = b.createModule(.{
        .root_source_file = b.path("conformance/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    conformance_mod.addImport("treesitter", mod);
    const conformance_exe = b.addExecutable(.{ .name = "conformance", .root_module = conformance_mod });
    const install_conformance = b.addInstallArtifact(conformance_exe, .{});
    const run_conformance = b.addRunArtifact(conformance_exe);
    run_conformance.step.dependOn(&install_conformance.step);
    conformance_step.dependOn(&run_conformance.step);

    const lib = b.addLibrary(.{
        .name = "treesitter",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/treesitter.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);

    const docs_step = b.step("docs", "Generate library documentation");
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);

    const test_all_step = b.step("test-all", "Run tests, benchmarks, and all runnable examples");
    test_all_step.dependOn(test_step);
    test_all_step.dependOn(bench_step);
    test_all_step.dependOn(run_all_examples);
}
