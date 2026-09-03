const std = @import("std");
const core = @import("../core/core.zig");
const language_mod = @import("../language/language.zig");
const tree_mod = @import("../tree/tree.zig");
const node_mod = @import("../tree/node.zig");
const pattern_mod = @import("pattern.zig");
const capture_mod = @import("capture.zig");
const predicate_mod = @import("predicate.zig");
const matcher_mod = @import("matcher.zig");

pub const QueryCursorOptions = struct {
    start_byte: u32 = 0,
    end_byte: u32 = std.math.maxInt(u32),
    start_point: core.Point = .{},
    end_point: core.Point = .{ .row = std.math.maxInt(u32), .column = std.math.maxInt(u32) },
    match_limit: u32 = std.math.maxInt(u32),
};

pub const QueryCursor = struct {
    gpa: std.mem.Allocator,
    matches: std.ArrayList(capture_mod.Match) = .empty,
    capture_lists: std.ArrayList([]capture_mod.Capture) = .empty,
    pos: usize = 0,
    options: QueryCursorOptions = .{},

    pub fn init(gpa: std.mem.Allocator) QueryCursor {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *QueryCursor) void {
        for (self.capture_lists.items) |list| self.gpa.free(list);
        self.capture_lists.deinit(self.gpa);
        self.matches.deinit(self.gpa);
        self.* = undefined;
    }

    pub fn reset(self: *QueryCursor) void {
        for (self.capture_lists.items) |list| self.gpa.free(list);
        self.capture_lists.clearRetainingCapacity();
        self.matches.clearRetainingCapacity();
        self.pos = 0;
    }

    pub fn resetAll(self: *QueryCursor) void {
        self.reset();
        self.options = .{};
    }

    pub fn setByteRange(self: *QueryCursor, start: u32, end: u32) void {
        self.options.start_byte = start;
        self.options.end_byte = end;
    }

    pub fn setPointRange(self: *QueryCursor, start: core.Point, end: core.Point) void {
        self.options.start_point = start;
        self.options.end_point = end;
    }

    pub fn setMatchLimit(self: *QueryCursor, limit: u32) void {
        self.options.match_limit = limit;
    }

    pub fn execute(
        self: *QueryCursor,
        language: language_mod.Language,
        patterns: []const pattern_mod.Pattern,
        nodes: []const pattern_mod.PatternNode,
        capture_names: []const []const u8,
        tree: *const tree_mod.Tree,
    ) std.mem.Allocator.Error!void {
        self.reset();
        if (tree.pool.nodes.items.len == 0) return;
        var matcher = try matcher_mod.Matcher.init(self.gpa, language, nodes, capture_names);
        defer matcher.deinit();
        var count: u32 = 0;
        var stack = std.ArrayList(node_mod.Node).empty;
        defer stack.deinit(self.gpa);
        try stack.append(self.gpa, tree.rootNode());
        while (stack.pop()) |node| {
            for (patterns, 0..) |pat, pi| {
                if (count >= self.options.match_limit) return;
                const mark = matcher.scratch.items.len;
                if (!self.inRange(node)) {
                    continue;
                }
                // Hot path: leaf patterns skip the sequence matcher.
                const matched = if (nodes[pat.root].children.len == 0)
                    matcher.matchLeaf(pat.root, node)
                else
                    matcher.collectRootCaptures(pat.root, node);
                if (matched) {
                    const caps = matcher.takeScratch()[mark..];
                    var keep = true;
                    for (pat.predicates) |pred| {
                        if (!predicate_mod.evaluatePredicate(pred, caps)) {
                            keep = false;
                            break;
                        }
                    }
                    if (keep) {
                        const owned = try self.gpa.dupe(capture_mod.Capture, caps);
                        try self.capture_lists.append(self.gpa, owned);
                        try self.matches.append(self.gpa, .{
                            .pattern_index = @as(u32, @intCast(pi)),
                            .captures = owned,
                        });
                        count += 1;
                    }
                }
                matcher.resetScratch(mark);
            }
            const n = node.childCount();
            var i = n;
            while (i > 0) {
                i -= 1;
                if (node.child(i)) |c| try stack.append(self.gpa, c);
            }
        }
    }

    fn inRange(self: *const QueryCursor, node: node_mod.Node) bool {
        if (node.endByte() <= self.options.start_byte) return false;
        if (node.startByte() >= self.options.end_byte) return false;
        return true;
    }

    pub fn nextMatch(self: *QueryCursor) ?*const capture_mod.Match {
        if (self.pos >= self.matches.items.len) return null;
        const m = &self.matches.items[self.pos];
        self.pos += 1;
        return m;
    }

    pub fn matchCount(self: *const QueryCursor) usize {
        return self.matches.items.len;
    }

    pub fn remainingMatches(self: *const QueryCursor) usize {
        return self.matches.items.len - @min(self.pos, self.matches.items.len);
    }
};
