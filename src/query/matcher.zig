const std = @import("std");
const language_mod = @import("../language/language.zig");
const tree_mod = @import("../tree/tree.zig");
const node_mod = @import("../tree/node.zig");
const pattern_mod = @import("pattern.zig");
const capture_mod = @import("capture.zig");
const predicate_mod = @import("predicate.zig");

pub const NO_ID: u16 = std.math.maxInt(u16);

pub const Matcher = struct {
    gpa: std.mem.Allocator,
    language: language_mod.Language,
    nodes: []const pattern_mod.PatternNode,
    capture_names: []const []const u8,
    /// Resolved symbol per pattern node (`NO_ID` falls back to name
    /// comparison): names resolve once, matches compare ids.
    ids: []u16 = &.{},
    scratch: std.ArrayList(capture_mod.Capture) = .empty,

    pub fn init(
        gpa: std.mem.Allocator,
        language: language_mod.Language,
        nodes: []const pattern_mod.PatternNode,
        capture_names: []const []const u8,
    ) std.mem.Allocator.Error!Matcher {
        const ids = try gpa.alloc(u16, nodes.len);
        errdefer gpa.free(ids);
        for (nodes, 0..) |pat, i| {
            ids[i] = switch (pat.kind) {
                .wildcard => NO_ID,
                .named => language.symbolForName(pat.name, true) orelse NO_ID,
                .anonymous => language.symbolForName(pat.name, false) orelse NO_ID,
            };
        }
        return .{ .gpa = gpa, .language = language, .nodes = nodes, .capture_names = capture_names, .ids = ids };
    }

    pub fn deinit(self: *Matcher) void {
        self.scratch.deinit(self.gpa);
        self.gpa.free(self.ids);
    }

    fn resolvedId(self: *const Matcher, pat_idx: u32) u16 {
        if (pat_idx >= self.ids.len) return NO_ID;
        return self.ids[pat_idx];
    }

    /// Kind, name (id-first), and negated-field checks shared by every
    /// entry point.
    fn kindMatches(self: *Matcher, pat_idx: u32, node: node_mod.Node) bool {
        const pat = self.nodes[pat_idx];
        switch (pat.kind) {
            .wildcard => {
                if (!node.isNamed()) return false;
            },
            .named => {
                if (!node.isNamed()) return false;
                const id = self.resolvedId(pat_idx);
                if (id != NO_ID) {
                    if (node.symbol() != id and !self.supertypeMatches(pat.name, node)) return false;
                } else if (!std.mem.eql(u8, node.nodeType(), pat.name)) {
                    if (!self.supertypeMatches(pat.name, node)) return false;
                }
            },
            .anonymous => {
                if (node.isNamed()) return false;
                const id = self.resolvedId(pat_idx);
                if (id != NO_ID) {
                    if (node.symbol() != id) return false;
                } else if (!std.mem.eql(u8, node.nodeType(), pat.name)) {
                    return false;
                }
            },
        }
        for (pat.negated_fields) |field| {
            if (node.childByFieldName(field) != null) return false;
        }
        return true;
    }

    pub fn nodeMatches(self: *Matcher, pat_idx: u32, node: node_mod.Node) bool {
        if (!self.kindMatches(pat_idx, node)) return false;
        const pat = self.nodes[pat_idx];
        if (pat.children.len == 0) return true;
        return self.childrenMatch(pat_idx, node);
    }

    fn supertypeMatches(self: *Matcher, name: []const u8, node: node_mod.Node) bool {
        const super_id = self.language.symbolForName(name, true) orelse return false;
        if (!self.language.symbolIsSupertype(super_id)) return false;
        // Subtype expansion: a pattern naming a supertype matches the
        // supertype itself and every registered subtype.
        if (node.symbol() == super_id) return true;
        for (self.language.subtypesOf(super_id)) |sub| {
            if (node.symbol() == sub) return true;
        }
        return false;
    }

    /// Fast path for leaf patterns (no children): kind check plus an
    /// optional capture, without entering the sequence matcher.
    pub fn matchLeaf(self: *Matcher, pat_idx: u32, node: node_mod.Node) bool {
        if (!self.kindMatches(pat_idx, node)) return false;
        const pat = self.nodes[pat_idx];
        const mark = self.scratch.items.len;
        if (!self.recordCapture(pat, node)) {
            self.scratch.items.len = mark;
            return false;
        }
        return true;
    }

    fn childrenMatch(self: *Matcher, pat_idx: u32, node: node_mod.Node) bool {
        const pat = self.nodes[pat_idx];
        const saved = self.scratch.items.len;
        const ok = self.matchSequence(pat.children, pat.child_fields, node, 0, 0, pat.anchor_before, pat.anchor_after);
        if (!ok) self.scratch.items.len = saved;
        return ok;
    }

    /// First named child at or after `from`, if any. Anchors ignore
    /// anonymous nodes, mirroring upstream.
    fn firstNamedIndex(node: node_mod.Node, from: u32) ?u32 {
        var i = from;
        const count = node.childCount();
        while (i < count) : (i += 1) {
            if ((node.child(i) orelse continue).isNamed()) return i;
        }
        return null;
    }

    /// Whether any named child sits in `[from, to)`.
    fn gapHasNamed(node: node_mod.Node, from: u32, to: u32) bool {
        var i = from;
        const count = node.childCount();
        while (i < to and i < count) : (i += 1) {
            if ((node.child(i) orelse continue).isNamed()) return true;
        }
        return false;
    }

    fn matchSequence(
        self: *Matcher,
        children: []const u32,
        fields: []const ?[]const u8,
        node: node_mod.Node,
        pi: usize,
        ci: u32,
        anchor_before: bool,
        anchor_after: bool,
    ) bool {
        if (pi >= children.len) {
            // Trailing anchor: no named siblings may follow the match.
            if (anchor_after) {
                var i = ci;
                while (i < node.childCount()) : (i += 1) {
                    if ((node.child(i) orelse continue).isNamed()) return false;
                }
            }
            return true;
        }
        const child_pat = self.nodes[children[pi]];
        const field = if (pi < fields.len) fields[pi] else null;
        const count = node.childCount();
        // Leading anchor: matching starts at the first named child
        // (anonymous pattern children match the exact first child:
        // nothing precedes them). Anchors ignore anonymous nodes.
        const start_ci = if (pi == 0 and anchor_before) blk: {
            if (child_pat.kind == .anonymous) break :blk ci;
            break :blk firstNamedIndex(node, ci) orelse {
                // No named children left: only zero-width paths proceed.
                return switch (child_pat.quantifier) {
                    .one, .one_or_more => false,
                    .optional, .zero_or_more => self.matchSequence(children, fields, node, pi + 1, ci, false, anchor_after),
                };
            };
        } else ci;
        switch (child_pat.quantifier) {
            .one => {
                if (pi == 0 and anchor_before) {
                    const mark = self.scratch.items.len;
                    if (self.tryChild(children[pi], field, node, start_ci)) {
                        if (self.matchSequence(children, fields, node, pi + 1, start_ci + 1, false, anchor_after)) return true;
                    }
                    self.scratch.items.len = mark;
                    return false;
                }
                var i = start_ci;
                while (i < count) : (i += 1) {
                    const mark = self.scratch.items.len;
                    // Between-anchor: no named nodes between the previous
                    // match and this candidate.
                    if (child_pat.anchor_before and gapHasNamed(node, ci, i)) {
                        self.scratch.items.len = mark;
                        continue;
                    }
                    if (self.tryChild(children[pi], field, node, i)) {
                        if (self.matchSequence(children, fields, node, pi + 1, i + 1, false, anchor_after)) return true;
                    }
                    self.scratch.items.len = mark;
                }
                return false;
            },
            .optional => {
                const mark = self.scratch.items.len;
                if (start_ci < count) {
                    const m2 = self.scratch.items.len;
                    if ((!child_pat.anchor_before or !gapHasNamed(node, ci, start_ci)) and
                        self.tryChild(children[pi], field, node, start_ci))
                    {
                        if (self.matchSequence(children, fields, node, pi + 1, start_ci + 1, false, anchor_after)) return true;
                    }
                    self.scratch.items.len = m2;
                }
                self.scratch.items.len = mark;
                return self.matchSequence(children, fields, node, pi + 1, ci, false, anchor_after);
            },
            .zero_or_more, .one_or_more => {
                const min: usize = if (child_pat.quantifier == .one_or_more) 1 else 0;
                return self.matchRepeat(children, fields, node, pi, start_ci, ci, 0, min, anchor_after, child_pat.anchor_before);
            },
        }
    }

    fn matchRepeat(
        self: *Matcher,
        children: []const u32,
        fields: []const ?[]const u8,
        node: node_mod.Node,
        pi: usize,
        ci: u32,
        gap_from: u32,
        matched: usize,
        min: usize,
        anchor_after: bool,
        anchored_first: bool,
    ) bool {
        const count = node.childCount();
        var i = ci;
        while (i < count) : (i += 1) {
            const mark = self.scratch.items.len;
            // The first repetition honors a between-anchor; later ones
            // are consecutive by construction.
            if (anchored_first and matched == 0 and gapHasNamed(node, gap_from, i)) {
                self.scratch.items.len = mark;
                break;
            }
            if (self.tryChild(children[pi], fields[pi], node, i)) {
                if (self.matchRepeat(children, fields, node, pi, i + 1, gap_from, matched + 1, min, anchor_after, anchored_first)) return true;
            }
            self.scratch.items.len = mark;
            break;
        }
        if (matched < min) return false;
        return self.matchSequence(children, fields, node, pi + 1, ci + @as(u32, @intCast(matched)), false, anchor_after);
    }

    fn tryChild(self: *Matcher, pat_idx: u32, field: ?[]const u8, parent: node_mod.Node, ci: u32) bool {
        const child = parent.child(ci) orelse return false;
        if (field) |f| {
            const actual = parent.fieldNameForChild(ci);
            if (actual == null or !std.mem.eql(u8, actual.?, f)) return false;
        }
        const mark = self.scratch.items.len;
        if (!self.nodeMatchesInner(pat_idx, child)) {
            self.scratch.items.len = mark;
            return false;
        }
        return true;
    }

    fn nodeMatchesInner(self: *Matcher, pat_idx: u32, node: node_mod.Node) bool {
        if (!self.kindMatches(pat_idx, node)) return false;
        const pat = self.nodes[pat_idx];
        if (!self.recordCapture(pat, node)) return false;
        if (pat.children.len == 0) return true;
        return self.childrenMatch(pat_idx, node);
    }

    fn recordCapture(self: *Matcher, pat: pattern_mod.PatternNode, node: node_mod.Node) bool {
        const cap = pat.capture orelse return true;
        if (cap >= self.capture_names.len) return false;
        self.scratch.append(self.gpa, .{
            .name = self.capture_names[cap],
            .name_index = cap,
            .node = node,
        }) catch return false;
        return true;
    }

    pub fn collectRootCaptures(self: *Matcher, pat_idx: u32, node: node_mod.Node) bool {
        return self.nodeMatchesInner(pat_idx, node);
    }

    pub fn takeScratch(self: *Matcher) []capture_mod.Capture {
        return self.scratch.items;
    }

    pub fn resetScratch(self: *Matcher, len: usize) void {
        self.scratch.items.len = len;
    }
};

// (Trees are assembled directly so these tests need no parser.)

test "matcher: supertype pattern matches registered subtypes" {
    const symbols_mod = @import("../language/symbols.zig");
    const subtree_mod = @import("../tree/subtree.zig");
    const syn_symbols: []const symbols_mod.SymbolInfo = &.{
        .{ .id = 11, .name = "expression", .kind = .non_terminal, .metadata = .{ .named = true, .supertype = true } },
        .{ .id = 12, .name = "term", .kind = .non_terminal, .metadata = .{ .named = true } },
    };
    const syn_subtypes: []const u16 = &.{12};
    const syn_map = [_]language_mod.SupertypeEntry{.{ .supertype = 11, .subtypes = syn_subtypes }};
    const syn_supers: []const u16 = &.{11};
    const syn_lang = language_mod.Language{
        .symbols = syn_symbols,
        .supertype_map = &syn_map,
        .supertypes = syn_supers,
    };
    // Tree holding a single `term` node, typed by the real grammar.
    var pool = subtree_mod.SubtreePool{};
    const idx = try pool.pushNode(std.testing.allocator, .{
        .symbol = 12,
        .start_byte = 0,
        .end_byte = 1,
        .start_point = .{},
        .end_point = .{ .row = 0, .column = 1 },
        .named = true,
        .visible = true,
    });
    const source = try std.testing.allocator.dupe(u8, "x");
    var tree = tree_mod.Tree{
        .gpa = std.testing.allocator,
        .language = language_mod.expression_language,
        .source = source,
        .pool = pool,
        .root_index = idx,
    };
    defer tree.deinit();
    const node = tree.rootNode();
    try std.testing.expectEqualStrings("term", node.nodeType());

    var pats = [_]pattern_mod.PatternNode{
        .{ .kind = .named, .name = "expression" },
        .{ .kind = .named, .name = "term" },
        .{ .kind = .named, .name = "number" },
    };
    var matcher = try Matcher.init(std.testing.allocator, syn_lang, &pats, &.{});
    defer matcher.deinit();
    // Supertype name matches the subtype node through the map.
    try std.testing.expect(matcher.nodeMatches(0, node));
    // Exact names still match directly.
    try std.testing.expect(matcher.nodeMatches(1, node));
    // Unknown names never match.
    try std.testing.expect(!matcher.nodeMatches(2, node));
}
