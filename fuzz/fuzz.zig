const std = @import("std");
const treesitter = @import("treesitter");

/// Fuzz target over the parser and the query compiler: `zig build fuzz`.
/// Generates pseudo-random sources from a small expression alphabet (plus
/// hostile bytes) with a seeded PRNG, parses them, and compiles random
/// query strings. Any panic, index-out-of-bounds, or leak (DebugAllocator
/// checks on exit) fails the run. Allocation failures are tolerated and
/// counted, matching the library's fallible API contract.
///
/// Options: `-Dfuzz-iterations=<n>` (default 2000), `-Dfuzz-seed=<n>`
/// (default 0xC0FFEE).
const alphabet = "abcXYZ019 +*-/()_\t\n@#$.\"':;!?";

/// Self-contained splitmix64 PRNG (no std.Random API dependency).
const Rng = struct {
    state: u64,
    fn next(self: *Rng) u64 {
        var z = self.state +% 0x9E3779B97F4A7C15;
        self.state = z;
        z = (z ^ (z >> 30)) *% 0xBF58476D1CE4E5B9;
        z = (z ^ (z >> 27)) *% 0x94D049BB133111EB;
        return z ^ (z >> 31);
    }
    fn below(self: *Rng, n: usize) usize {
        if (n == 0) return 0;
        return @as(usize, @intCast(self.next() % @as(u64, @intCast(n))));
    }
};

fn nextSource(rng: *Rng, buf: []u8) []u8 {
    const len = rng.below(65);
    for (buf[0..len], 0..) |*b, i| {
        _ = i;
        b.* = alphabet[rng.below(alphabet.len)];
    }
    return buf[0..len];
}

const query_alphabet = "identifiernumber()@_.:\"*+?#! \t\nabcdefxyz_";

fn nextQuery(rng: *Rng, buf: []u8) []u8 {
    const len = rng.below(49);
    for (buf[0..len], 0..) |*b, i| {
        _ = i;
        b.* = query_alphabet[rng.below(query_alphabet.len)];
    }
    return buf[0..len];
}

/// Structured fragments that frequently assemble into valid queries,
/// exercising the compiler success paths plus matcher/cursor execution.
const query_fragments: []const []const u8 = &.{
    "(identifier)",
    "(number)",
    "(expression)",
    "(term)",
    "(factor)",
    "(program)",
    "(_)",
    "\"+\"",
    "\"*\"",
    " ",
    ".",
    "(@x)",
    " @id",
    " @x",
    " left:",
    " right:",
    " !left",
    " (#eq? @x \"a\")",
    " (#any-eq? @x \"a\")",
    " (#match? @x \"a\")",
    " (#any-match? @x \"a\")",
    " (#contains? @x \"a\")",
    " (#any-of? @x \"a\" \"b\")",
    " (#is? @x named)",
    " (#set! kind \"variable\")",
    " (#select-adjacent! @x @x)",
    " (#strip! @x \"a\")",
    "?",
    "*",
    "+",
};

fn nextStructuredQuery(rng: *Rng, buf: []u8) []u8 {
    var len: usize = 0;
    const parts = 1 + rng.below(4);
    var p: usize = 0;
    while (p < parts and len < buf.len) : (p += 1) {
        const frag = query_fragments[rng.below(query_fragments.len)];
        const n = @min(frag.len, buf.len - len);
        @memcpy(buf[len .. len + n], frag[0..n]);
        len += n;
    }
    return buf[0..len];
}

pub fn main(init: std.process.Init.Minimal) !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var arg_it = try std.process.Args.Iterator.initAllocator(init.args, gpa);
    defer arg_it.deinit();
    _ = arg_it.skip(); // executable name
    var iterations: usize = 2000;
    var seed: u64 = 0xC0FFEE;
    while (arg_it.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--iterations=")) {
            iterations = std.fmt.parseInt(usize, arg["--iterations=".len..], 10) catch iterations;
        } else if (std.mem.startsWith(u8, arg, "--seed=")) {
            seed = std.fmt.parseInt(u64, arg["--seed=".len..], 10) catch seed;
        }
    }

    var prng = Rng{ .state = seed | 1 };

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(treesitter.expression_language);

    var src_buf: [64]u8 = undefined;
    var q_buf: [128]u8 = undefined;
    var parsed: usize = 0;
    var parse_errors: usize = 0;
    var queries_ok: usize = 0;
    var queries_rejected: usize = 0;
    var matches_seen: usize = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const src = nextSource(&prng, &src_buf);
        var tree_opt: ?treesitter.Tree = null;
        if (parser.parseString(src)) |t| {
            tree_opt = t;
            parsed += 1;
        } else |_| {
            parse_errors += 1;
        }
        // Alternate pure noise with fragment-assembled queries so both
        // the compiler rejection paths and matcher execution get hit.
        const qsrc = if (i % 2 == 0)
            nextQuery(&prng, &q_buf)
        else
            nextStructuredQuery(&prng, &q_buf);
        if (treesitter.Query.compile(gpa, treesitter.expression_language, qsrc)) |q| {
            var query = q;
            defer query.deinit();
            queries_ok += 1;
            // On success, also execute against the fuzzed tree to cover
            // the matcher, predicates, and cursor iteration.
            if (tree_opt) |*t| {
                var qc = treesitter.QueryCursor.init(gpa);
                defer qc.deinit();
                qc.execute(
                    treesitter.expression_language,
                    query.patterns(),
                    query.nodes(),
                    query.captureNames(),
                    t,
                ) catch {};
                while (qc.nextMatch()) |_| matches_seen += 1;
            }
        } else |_| {
            queries_rejected += 1;
        }
        if (tree_opt) |*t| t.deinit();
    }

    std.debug.print(
        "fuzz: {d} iterations (seed {d}): parses ok={d} err={d}, queries ok={d} rejected={d} matches={d}\n",
        .{ iterations, seed, parsed, parse_errors, queries_ok, queries_rejected, matches_seen },
    );
}
