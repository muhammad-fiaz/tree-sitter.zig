const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expression_language;

const io = std.Io.Threaded.global_single_threaded.io();

fn now() std.Io.Timestamp {
    return std.Io.Timestamp.now(io, .awake);
}

fn msSince(t0: std.Io.Timestamp) i64 {
    return t0.durationTo(now()).toMilliseconds();
}

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(gpa);
    for (0..20000) |i| {
        if (i > 0) try buf.appendSlice(gpa, " + ");
        try buf.appendSlice(gpa, "v");
    }
    const source = buf.items;
    std.debug.print("source bytes: {d}\n", .{source.len});

    var t0 = now();
    var tree = try parser.parseString(source);
    std.debug.print("initial parse: {d} ms, nodes={d}\n", .{ msSince(t0), tree.nodeCount() });

    t0 = now();
    var tree2 = try parser.parseString(source);
    std.debug.print("repeated parse: {d} ms\n", .{msSince(t0)});
    tree2.deinit();

    const edit = treesitter.InputEdit{
        .start_byte = 0,
        .old_end_byte = 1,
        .new_end_byte = 2,
        .start_point = .{},
        .old_end_point = .{ .row = 0, .column = 1 },
        .new_end_point = .{ .row = 0, .column = 2 },
    };
    var grown = std.ArrayList(u8).empty;
    defer grown.deinit(gpa);
    try grown.appendSlice(gpa, "wx");
    try grown.appendSlice(gpa, source[1..]);

    t0 = now();
    var tree3 = try parser.parse(&tree, edit, grown.items);
    std.debug.print("small edit incremental: {d} ms, reused_nodes={d}\n", .{ msSince(t0), parser.reused_node_count });
    tree3.deinit();

    t0 = now();
    var tree4 = try parser.parse(&tree, edit, grown.items);
    std.debug.print("incremental reparse: {d} ms\n", .{msSince(t0)});
    tree4.deinit();

    t0 = now();
    var count: usize = 0;
    var stack = std.ArrayList(treesitter.Node).empty;
    defer stack.deinit(gpa);
    try stack.append(gpa, tree.rootNode());
    while (stack.pop()) |node| {
        count += 1;
        var i = node.childCount();
        while (i > 0) {
            i -= 1;
            try stack.append(gpa, node.child(i).?);
        }
    }
    std.debug.print("tree traversal: {d} ms, visited={d}\n", .{ msSince(t0), count });

    var query = try treesitter.Query.compile(gpa, grammar, "(identifier) @id");
    defer query.deinit();
    var qcursor = treesitter.QueryCursor.init(gpa);
    defer qcursor.deinit();
    t0 = now();
    try qcursor.execute(grammar, query.patterns(), query.nodes(), query.captureNames(), &tree);
    std.debug.print("query execution: {d} ms, matches={d}\n", .{ msSince(t0), qcursor.matchCount() });

    tree.deinit();
}
