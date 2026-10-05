const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expressionLanguage;

const ParseTask = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    node_count: usize = 0,
    has_error: bool = false,

    fn run(self: *@This()) void {
        var parser = treesitter.Parser.init(self.allocator);
        defer parser.deinit();
        parser.setLanguage(grammar) catch unreachable;

        var tree = parser.parseString(self.source) catch unreachable;
        defer tree.deinit();

        self.node_count = tree.nodeCount();
        self.has_error = tree.hasError();
    }
};

const QueryWorker = struct {
    tree: *const treesitter.Tree,
    query: *const treesitter.Query,
    match_count: usize = 0,

    fn run(self: *@This()) void {
        var cursor = treesitter.QueryCursor.init(self.tree.gpa);
        defer cursor.deinit();

        cursor.execute(
            grammar,
            self.query.patterns(),
            self.query.nodes(),
            self.query.captureNames(),
            self.tree,
        ) catch unreachable;

        var count: usize = 0;
        while (cursor.nextMatch()) |_| {
            count += 1;
        }
        self.match_count = count;
    }
};

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    std.debug.print("1. Concurrent parsing with isolated parsers across OS threads:\n", .{});
    var task1 = ParseTask{ .allocator = gpa, .source = "total + price * count" };
    var task2 = ParseTask{ .allocator = gpa, .source = "a * (b + c) / d - e" };
    var task3 = ParseTask{ .allocator = gpa, .source = "10 + 20 + 30 + 40" };

    const t1 = try std.Thread.spawn(.{}, ParseTask.run, .{&task1});
    const t2 = try std.Thread.spawn(.{}, ParseTask.run, .{&task2});
    const t3 = try std.Thread.spawn(.{}, ParseTask.run, .{&task3});

    t1.join();
    t2.join();
    t3.join();

    std.debug.print("   thread 1: nodes={d} error={}\n", .{ task1.node_count, task1.has_error });
    std.debug.print("   thread 2: nodes={d} error={}\n", .{ task2.node_count, task2.has_error });
    std.debug.print("   thread 3: nodes={d} error={}\n", .{ task3.node_count, task3.has_error });

    std.debug.print("\n2. Concurrent queries over a shared immutable tree:\n", .{});
    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var shared_tree = try parser.parseString("alpha * beta + gamma * delta + epsilon");
    defer shared_tree.deinit();

    var compiled_query = try parser.compileQuery("(identifier) @id");
    defer compiled_query.deinit();

    var q_worker1 = QueryWorker{ .tree = &shared_tree, .query = &compiled_query };
    var q_worker2 = QueryWorker{ .tree = &shared_tree, .query = &compiled_query };

    const qt1 = try std.Thread.spawn(.{}, QueryWorker.run, .{&q_worker1});
    const qt2 = try std.Thread.spawn(.{}, QueryWorker.run, .{&q_worker2});

    qt1.join();
    qt2.join();

    std.debug.print("   worker 1 matches: {d}\n", .{q_worker1.match_count});
    std.debug.print("   worker 2 matches: {d}\n", .{q_worker2.match_count});
}
