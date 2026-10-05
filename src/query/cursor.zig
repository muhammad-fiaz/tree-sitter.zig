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
    containing_start_byte: u32 = 0,
    containing_end_byte: u32 = std.math.maxInt(u32),
    containing_start_point: core.Point = .{},
    containing_end_point: core.Point = .{ .row = std.math.maxInt(u32), .column = std.math.maxInt(u32) },
    max_start_depth: ?u32 = null,
    match_limit: u32 = std.math.maxInt(u32),
};

/// Stateful query execution cursor.
///
/// **Ownership**: `QueryCursor` owns its match list and capture slices via
/// `gpa`.  Call `deinit` to free them.  It borrows the `Tree` passed to
/// `execute`; the tree must outlive the cursor.
///
/// **Concurrency**: a `QueryCursor` MUST NOT be accessed concurrently from
/// multiple threads.  For parallel queries over a shared immutable `Tree`,
/// create one independent `QueryCursor` per thread.
pub const QueryCursor = struct {
    gpa: std.mem.Allocator,
    matches: std.ArrayList(capture_mod.Match) = .empty,
    capture_lists: std.ArrayList([]capture_mod.Capture) = .empty,
    pos: usize = 0,
    current_match_index: usize = 0,
    current_capture_index: u32 = 0,
    exceeded_match_limit: bool = false,
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
        self.current_match_index = 0;
        self.current_capture_index = 0;
        self.exceeded_match_limit = false;
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

    pub fn setContainingByteRange(self: *QueryCursor, start: u32, end: u32) void {
        self.options.containing_start_byte = start;
        self.options.containing_end_byte = end;
    }

    pub fn setContainingPointRange(self: *QueryCursor, start: core.Point, end: core.Point) void {
        self.options.containing_start_point = start;
        self.options.containing_end_point = end;
    }

    pub fn setMaxStartDepth(self: *QueryCursor, depth: ?u32) void {
        self.options.max_start_depth = depth;
    }

    pub fn setMatchLimit(self: *QueryCursor, limit: u32) void {
        self.options.match_limit = limit;
    }

    pub fn didExceedMatchLimit(self: QueryCursor) bool {
        return self.exceeded_match_limit;
    }

    pub fn matchLimit(self: QueryCursor) ?u32 {
        return if (self.options.match_limit == std.math.maxInt(u32)) null else self.options.match_limit;
    }

    pub fn removeMatch(self: *QueryCursor, match_id: u32) void {
        if (match_id < self.matches.items.len) {
            _ = self.matches.orderedRemove(match_id);
            if (self.pos > match_id) self.pos -= 1;
            if (self.current_match_index > match_id) self.current_match_index -= 1;
        }
    }

    pub fn nextCapture(self: *QueryCursor, out_match: *capture_mod.Match, out_capture_index: *u32) bool {
        while (self.current_match_index < self.matches.items.len) {
            const m = &self.matches.items[self.current_match_index];
            if (self.current_capture_index < m.captures.len) {
                out_match.* = m.*;
                out_capture_index.* = self.current_capture_index;
                self.current_capture_index += 1;
                return true;
            }
            self.current_match_index += 1;
            self.current_capture_index = 0;
        }
        return false;
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

        const StackEntry = struct {
            node: node_mod.Node,
            depth: u32,
        };

        var stack = std.ArrayList(StackEntry).empty;
        defer stack.deinit(self.gpa);
        try stack.append(self.gpa, .{ .node = tree.rootNode(), .depth = 0 });

        while (stack.pop()) |entry| {
            const node = entry.node;
            const depth = entry.depth;

            const skip_start = if (self.options.max_start_depth) |max_d| depth > max_d else false;

            if (!skip_start) {
                for (patterns, 0..) |pat, pi| {
                    if (count >= self.options.match_limit) {
                        self.exceeded_match_limit = true;
                        return;
                    }
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
            }

            const n = node.childCount();
            var i = n;
            while (i > 0) {
                i -= 1;
                if (node.child(i)) |c| try stack.append(self.gpa, .{ .node = c, .depth = depth + 1 });
            }
        }
    }

    fn inRange(self: *const QueryCursor, node: node_mod.Node) bool {
        if (node.endByte() <= self.options.start_byte) return false;
        if (node.startByte() >= self.options.end_byte) return false;
        if (self.options.containing_start_byte > 0 and node.startByte() < self.options.containing_start_byte) return false;
        if (self.options.containing_end_byte < std.math.maxInt(u32) and node.endByte() > self.options.containing_end_byte) return false;
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
