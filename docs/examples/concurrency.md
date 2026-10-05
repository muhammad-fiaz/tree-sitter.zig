---
description: Concurrency and I/O examples — multi-threading, thread-isolated parsers, shared immutable trees, and polymorphic std.Io contexts.
---

# Concurrency & I/O

## What you'll learn

- Running concurrent parsers across independent OS threads with zero lock contention.
- Sharing immutable `Tree` instances across worker threads for parallel traversals and queries.
- Configuring explicit `std.Io` contexts (single-threaded, multi-threaded, or custom).
- Parsing directly from streaming `std.Io.Reader` interfaces.
- Generating Graphviz DOT representations directly to `std.Io.Writer` buffers.

---

## Example 1: Multi-Threaded Parsing & Shared Immutable Trees

This program demonstrates Tree-sitter's thread-safety architecture in production environments. First, multiple worker threads parse different source texts concurrently using isolated `Parser` instances. Second, a single compiled `Tree` and `Query` are shared across threads to execute queries simultaneously without mutex locks:

```zig
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
```

### Running Example 1

```bash
zig build run-multithreading
```

### Expected output

```text
1. Concurrent parsing with isolated parsers across OS threads:
   thread 1: nodes=14 error=false
   thread 2: nodes=28 error=false
   thread 3: nodes=20 error=false

2. Concurrent queries over a shared immutable tree:
   worker 1 matches: 5
   worker 2 matches: 5
```

---

## Example 2: Explicit Single-Threaded and Custom `std.Io` Contexts

This program configures a parser with an explicit `std.Io` context, configures monotonic parse timeouts, parses a stream directly from a `std.Io.Reader`, and exports a Graphviz DOT representation to a `std.Io.Writer`:

```zig
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
```

### Running Example 2

```bash
zig build run-custom_io
```

### Expected output

```text
Configured parser with explicit std.Io context.
Set timeout to 5000000 micros.
Parsed from std.Io.Reader: total * (tax_rate + 1)
Tree node count: 19, has_error=false
Generated DOT graph: 913 bytes
DOT sample:
digraph tree {
  node_0 [label="identifier"];
  node_1 [label="factor"...
```

---

## How it works

1. **Parser Isolation**: Each `Parser` instance owns its stack, scratch memory, and reuse maps. Spawning worker threads with individual parsers requires no mutexes or synchronization primitives.
2. **Immutable Trees**: After a parse completes, the returned `Tree` is immutable. Its node pool, source buffer, and child offsets are fixed. Multiple threads can construct independent `TreeCursor` or `QueryCursor` instances and traverse the tree concurrently.
3. **Thread-Safe Queries**: A compiled `Query` contains immutable pattern bytecode and can be executed across multiple threads simultaneously.
4. **Polymorphic `std.Io`**: `Parser.setIo` accepts any `std.Io` context. Single-threaded embedded systems can pass single-threaded implementations, while servers can pass multi-threaded async loop contexts.
5. **Streaming I/O**: `Parser.parseReader` pulls bytes incrementally through `*std.Io.Reader` into a caller-controlled scratch buffer, enabling streaming parses from files, network sockets, or pipes.

## API used

- [Parser](/api/parser) — `Parser.init`, `Parser.setLanguage`, `Parser.parseString`, `Parser.parseReader`, `Parser.setIo`, `Parser.setTimeoutMicros`
- [Tree](/api/tree) — `Tree.nodeCount`, `Tree.hasError`, `Tree.writeDotGraph`, `Tree.printDotGraphToFile`
- [Query](/api/query) — `Query.compile`, `Parser.compileQuery`
- [Query Cursor](/api/query-cursor) — `QueryCursor.init`, `QueryCursor.execute`, `QueryCursor.nextMatch`
- [Input & I/O Reference](/reference/input-io) — `std.Io`, `ReaderSource`

## Related guides

- [Input & I/O Reference](/reference/input-io)
- [Parsing Source](/guide/parsing-source)
- [Performance & Benchmarks](/guide/performance)
