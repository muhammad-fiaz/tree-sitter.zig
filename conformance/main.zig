const std = @import("std");
const treesitter = @import("treesitter");
const conformance = treesitter.conformance;

const cases: []const []const u8 = conformance.corpus_files;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var passed: usize = 0;
    var failed: usize = 0;
    for (cases) |text| {
        var case = conformance.parseCase(gpa, text) catch |err| {
            std.debug.print("FAIL <unparsed>: {s}\n", .{@errorName(err)});
            failed += 1;
            continue;
        };
        defer case.deinit();
        conformance.runCase(gpa, &case) catch |err| {
            failed += 1;
            std.debug.print("FAIL [{s}] {s}: {s}\n", .{ case.grammar, case.name, @errorName(err) });
            const actual = conformance.renderActual(gpa, &case) catch continue;
            defer gpa.free(actual);
            std.debug.print("  actual:   {s}\n", .{actual});
            if (case.kind == .parse) std.debug.print("  expected: {s}\n", .{case.expected});
            continue;
        };
        passed += 1;
        std.debug.print("PASS [{s}] {s}\n", .{ case.grammar, case.name });
    }
    std.debug.print("{d} passed, {d} failed\n", .{ passed, failed });
    if (failed > 0) std.process.exit(1);
}
