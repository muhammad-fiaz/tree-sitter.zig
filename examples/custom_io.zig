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

    // 1. Explicitly configure polymorphic std.Io context
    const io_ctx = std.Io.Threaded.global_single_threaded.io();
    parser.setIo(io_ctx);
    std.debug.print("Configured parser with explicit std.Io context.\n", .{});

    // 2. Timeout configuration using std.Io monotonic clock
    parser.setTimeoutMicros(5_000_000); // 5 second timeout
    std.debug.print("Set timeout to {d} micros.\n", .{parser.timeoutMicros()});

    // 3. Stream parsing directly from a std.Io.Reader
    const text = "total * (tax_rate + 1)";
    var reader = std.Io.Reader.fixed(text);
    var buffer: [8]u8 = undefined;

    var tree = try parser.parseReader(&reader, &buffer);
    defer tree.deinit();

    std.debug.print("Parsed from std.Io.Reader: {s}\n", .{tree.rootNode().text()});
    std.debug.print("Tree node count: {d}, has_error={}\n", .{ tree.nodeCount(), tree.hasError() });

    // 4. Export syntax tree as Graphviz DOT graph to a std.Io.Writer
    var dot_buf: [2048]u8 = undefined;
    var writer = std.Io.Writer.fixed(&dot_buf);
    try tree.writeDotGraph(&writer);
    const dot_output = writer.buffered();

    std.debug.print("Generated DOT graph: {d} bytes\n", .{dot_output.len});
    std.debug.print("DOT sample:\n{s}...\n", .{dot_output[0..@min(dot_output.len, 70)]});
}
