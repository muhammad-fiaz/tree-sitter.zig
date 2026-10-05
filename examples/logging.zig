const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expressionLanguage;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    // Attach Tracer to record parse lifecycle events in memory
    var tracer = treesitter.Tracer.init(gpa, .{ .level = .off });
    defer tracer.deinit();
    parser.setTracer(&tracer);

    var tree = try parser.parseString("total + 42");
    defer tree.deinit();

    std.debug.print("Parsed tree has_error={} nodes={d}\n", .{ tree.hasError(), tree.nodeCount() });
    std.debug.print("Tracer recorded {d} lifecycle events:\n", .{tracer.count()});
    for (tracer.entries.items) |entry| {
        std.debug.print("  event: {s} offset={d} sym={d} state={d}\n", .{
            @tagName(entry.event),
            entry.byte_offset,
            entry.symbol,
            entry.state,
        });
    }
}
