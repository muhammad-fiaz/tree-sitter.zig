const std = @import("std");
const pattern_mod = @import("pattern.zig");
const predicate_mod = @import("predicate.zig");

pub const QueryParseError = error{
    OutOfMemory,
    UnexpectedEof,
    UnexpectedToken,
    InvalidSyntax,
    InvalidPredicate,
    /// A predicate or directive references a capture never declared by
    /// a node pattern.
    InvalidCapture,
};

pub const ParsedQuery = struct {
    gpa: std.mem.Allocator,
    source: []u8,
    nodes: std.ArrayList(pattern_mod.PatternNode),
    child_lists: std.ArrayList(std.ArrayList(u32)),
    field_lists: std.ArrayList(std.ArrayList(?[]const u8)),
    negated_field_lists: std.ArrayList(std.ArrayList([]const u8)),
    patterns: std.ArrayList(pattern_mod.Pattern),
    pattern_predicates: std.ArrayList(std.ArrayList(pattern_mod.Predicate)),
    pattern_settings: std.ArrayList(std.ArrayList(pattern_mod.Setting)),
    pattern_directives: std.ArrayList(std.ArrayList(pattern_mod.Directive)),
    predicate_args: std.ArrayList(std.ArrayList(pattern_mod.PredicateArg)),
    captures: std.ArrayList([]const u8),
    /// Captures attached to node patterns (vs auto-created by predicate
    /// references). Predicate/directive captures must be declared here.
    node_declared: std.ArrayList(bool),

    pub fn deinit(self: *ParsedQuery) void {
        for (self.patterns.items) |pat| {
            for (pat.predicates) |pred| self.gpa.free(pred.args);
            self.gpa.free(pat.predicates);
            self.gpa.free(pat.settings);
            for (pat.directives) |dir| self.gpa.free(dir.args);
            self.gpa.free(pat.directives);
        }
        for (self.child_lists.items) |*l| l.deinit(self.gpa);
        self.child_lists.deinit(self.gpa);
        for (self.field_lists.items) |*l| l.deinit(self.gpa);
        self.field_lists.deinit(self.gpa);
        for (self.negated_field_lists.items) |*l| l.deinit(self.gpa);
        self.negated_field_lists.deinit(self.gpa);
        for (self.pattern_predicates.items) |*l| l.deinit(self.gpa);
        self.pattern_predicates.deinit(self.gpa);
        for (self.pattern_settings.items) |*l| l.deinit(self.gpa);
        self.pattern_settings.deinit(self.gpa);
        for (self.pattern_directives.items) |*l| l.deinit(self.gpa);
        self.pattern_directives.deinit(self.gpa);
        for (self.predicate_args.items) |*l| l.deinit(self.gpa);
        self.predicate_args.deinit(self.gpa);
        self.nodes.deinit(self.gpa);
        self.patterns.deinit(self.gpa);
        self.captures.deinit(self.gpa);
        self.node_declared.deinit(self.gpa);
        self.gpa.free(self.source);
        self.* = undefined;
    }
};

const Cursor = struct {
    text: []const u8,
    pos: usize = 0,

    fn eof(self: *Cursor) bool {
        return self.pos >= self.text.len;
    }

    fn peek(self: *Cursor) ?u8 {
        self.skipTrivia();
        if (self.pos >= self.text.len) return null;
        return self.text[self.pos];
    }

    fn skipTrivia(self: *Cursor) void {
        while (self.pos < self.text.len) {
            const c = self.text[self.pos];
            if (c == ';') {
                while (self.pos < self.text.len and self.text[self.pos] != '\n') : (self.pos += 1) {}
            } else if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                self.pos += 1;
            } else {
                break;
            }
        }
    }

    fn expect(self: *Cursor, c: u8) QueryParseError!void {
        self.skipTrivia();
        if (self.pos >= self.text.len or self.text[self.pos] != c) return error.UnexpectedToken;
        self.pos += 1;
    }

    fn readString(self: *Cursor) QueryParseError![]const u8 {
        try self.expect('"');
        const start = self.pos;
        var end = start;
        var escaped = false;
        while (self.pos < self.text.len) {
            const c = self.text[self.pos];
            self.pos += 1;
            if (escaped) {
                escaped = false;
            } else if (c == '\\') {
                escaped = true;
            } else if (c == '"') {
                end = self.pos - 1;
                return self.text[start..end];
            }
        }
        return error.UnexpectedEof;
    }

    fn readSymbol(self: *Cursor) QueryParseError![]const u8 {
        self.skipTrivia();
        const start = self.pos;
        while (self.pos < self.text.len) {
            const c = self.text[self.pos];
            if (c == '(' or c == ')' or c == '[' or c == ']' or c == '"' or c == ';' or c == ' ' or
                c == '\t' or c == '\n' or c == '\r' or c == ':' or c == '@' or c == '#')
                break;
            self.pos += 1;
        }
        if (self.pos == start) return error.UnexpectedToken;
        return self.text[start..self.pos];
    }

    fn readCaptureName(self: *Cursor) QueryParseError![]const u8 {
        self.skipTrivia();
        if (self.pos >= self.text.len or self.text[self.pos] != '@') return error.UnexpectedToken;
        self.pos += 1;
        const start = self.pos;
        while (self.pos < self.text.len) {
            const c = self.text[self.pos];
            if (std.ascii.isAlphanumeric(c) or c == '_' or c == '.' or c == '-') {
                self.pos += 1;
            } else break;
        }
        if (self.pos == start) return error.UnexpectedToken;
        return self.text[start..self.pos];
    }
};

const PatternCollector = struct {
    preds: std.ArrayList(pattern_mod.Predicate),
    settings: std.ArrayList(pattern_mod.Setting),
    directives: std.ArrayList(pattern_mod.Directive),

    fn init() PatternCollector {
        return .{
            .preds = .empty,
            .settings = .empty,
            .directives = .empty,
        };
    }

    fn deinit(self: *PatternCollector, gpa: std.mem.Allocator) void {
        self.preds.deinit(gpa);
        self.settings.deinit(gpa);
        self.directives.deinit(gpa);
    }
};

fn dupePredicates(gpa: std.mem.Allocator, src: []const pattern_mod.Predicate) ![]pattern_mod.Predicate {
    const res = try gpa.alloc(pattern_mod.Predicate, src.len);
    var initialized: usize = 0;
    errdefer {
        for (res[0..initialized]) |p| gpa.free(p.args);
        gpa.free(res);
    }
    for (src, 0..) |p, i| {
        res[i] = p;
        res[i].args = try gpa.dupe(pattern_mod.PredicateArg, p.args);
        initialized += 1;
    }
    return res;
}

fn dupeDirectives(gpa: std.mem.Allocator, src: []const pattern_mod.Directive) ![]pattern_mod.Directive {
    const res = try gpa.alloc(pattern_mod.Directive, src.len);
    var initialized: usize = 0;
    errdefer {
        for (res[0..initialized]) |d| gpa.free(d.args);
        gpa.free(res);
    }
    for (src, 0..) |d, i| {
        res[i] = d;
        res[i].args = try gpa.dupe(pattern_mod.PredicateArg, d.args);
        initialized += 1;
    }
    return res;
}

fn collectTrailingPredicates(
    gpa: std.mem.Allocator,
    pq: *ParsedQuery,
    cursor: *Cursor,
    collector: *PatternCollector,
) QueryParseError!void {
    while (true) {
        cursor.skipTrivia();
        if (cursor.eof() or cursor.text[cursor.pos] != '(') break;
        const saved = cursor.pos;
        cursor.pos += 1;
        cursor.skipTrivia();
        if (cursor.pos < cursor.text.len and cursor.text[cursor.pos] == '#') {
            cursor.pos = saved;
            switch (try parsePredicate(gpa, pq, cursor)) {
                .pred => |pred| try collector.preds.append(gpa, pred),
                .setting => |setting| try collector.settings.append(gpa, setting),
                .general => |directive| try collector.directives.append(gpa, directive),
            }
        } else {
            cursor.pos = saved;
            break;
        }
    }
}

pub fn parse(gpa: std.mem.Allocator, source_text: []const u8) QueryParseError!ParsedQuery {
    var pq = ParsedQuery{
        .gpa = gpa,
        .source = try gpa.dupe(u8, source_text),
        .nodes = .empty,
        .child_lists = .empty,
        .field_lists = .empty,
        .negated_field_lists = .empty,
        .patterns = .empty,
        .pattern_predicates = .empty,
        .pattern_settings = .empty,
        .pattern_directives = .empty,
        .predicate_args = .empty,
        .captures = .empty,
        .node_declared = .empty,
    };
    errdefer pq.deinit();
    var cursor = Cursor{ .text = pq.source };
    while (true) {
        cursor.skipTrivia();
        if (cursor.eof()) break;
        const c = cursor.text[cursor.pos];
        if (c == '(') {
            // Check if this is a parenthesized alternation: ([ ... ] @cap (#pred ...))
            const saved_pos = cursor.pos;
            cursor.pos += 1;
            cursor.skipTrivia();
            const next_c = if (cursor.pos < cursor.text.len) cursor.text[cursor.pos] else 0;
            if (next_c == '[') {
                var collector = PatternCollector.init();
                errdefer collector.deinit(gpa);

                var alts = try parseAlternation(gpa, &pq, &cursor, &collector);
                defer alts.deinit(gpa);

                // Collect any inner predicates inside the parenthesized group
                try collectTrailingPredicates(gpa, &pq, &cursor, &collector);
                try cursor.expect(')');

                // Collect any trailing predicates after the closing ')'
                try collectTrailingPredicates(gpa, &pq, &cursor, &collector);

                const p_slice = try collector.preds.toOwnedSlice(gpa);
                defer if (alts.items.len == 0) gpa.free(p_slice);
                const s_slice = try collector.settings.toOwnedSlice(gpa);
                defer if (alts.items.len == 0) gpa.free(s_slice);
                const d_slice = try collector.directives.toOwnedSlice(gpa);
                defer if (alts.items.len == 0) gpa.free(d_slice);

                for (alts.items, 0..) |alt_root, i| {
                    const cur_p = if (i == 0) p_slice else try dupePredicates(gpa, p_slice);
                    const cur_s = if (i == 0) s_slice else try gpa.dupe(pattern_mod.Setting, s_slice);
                    const cur_d = if (i == 0) d_slice else try dupeDirectives(gpa, d_slice);

                    try pq.patterns.append(gpa, .{
                        .root = alt_root,
                        .predicates = cur_p,
                        .settings = cur_s,
                        .directives = cur_d,
                    });
                }
                continue;
            }
            cursor.pos = saved_pos;

            var collector = PatternCollector.init();
            errdefer collector.deinit(gpa);

            const is_group = isGroupStart(&cursor);
            const root = if (is_group)
                try parseGroup(gpa, &pq, &cursor, &collector)
            else
                try parseNode(gpa, &pq, &cursor, true, &collector);

            try collectTrailingPredicates(gpa, &pq, &cursor, &collector);

            try pq.patterns.append(gpa, .{
                .root = root,
                .predicates = try collector.preds.toOwnedSlice(gpa),
                .settings = try collector.settings.toOwnedSlice(gpa),
                .directives = try collector.directives.toOwnedSlice(gpa),
            });
        } else if (c == '[') {
            var collector = PatternCollector.init();
            errdefer collector.deinit(gpa);

            var alts = try parseAlternation(gpa, &pq, &cursor, &collector);
            defer alts.deinit(gpa);

            try collectTrailingPredicates(gpa, &pq, &cursor, &collector);

            const p_slice = try collector.preds.toOwnedSlice(gpa);
            defer if (alts.items.len == 0) gpa.free(p_slice);
            const s_slice = try collector.settings.toOwnedSlice(gpa);
            defer if (alts.items.len == 0) gpa.free(s_slice);
            const d_slice = try collector.directives.toOwnedSlice(gpa);
            defer if (alts.items.len == 0) gpa.free(d_slice);

            for (alts.items, 0..) |alt_root, i| {
                const cur_p = if (i == 0) p_slice else try dupePredicates(gpa, p_slice);
                const cur_s = if (i == 0) s_slice else try gpa.dupe(pattern_mod.Setting, s_slice);
                const cur_d = if (i == 0) d_slice else try dupeDirectives(gpa, d_slice);

                try pq.patterns.append(gpa, .{
                    .root = alt_root,
                    .predicates = cur_p,
                    .settings = cur_s,
                    .directives = cur_d,
                });
            }
        } else if (c == '"') {
            var collector = PatternCollector.init();
            errdefer collector.deinit(gpa);

            const root = try allocNode(gpa, &pq);
            pq.nodes.items[root] = .{ .kind = .anonymous, .name = try cursor.readString() };
            applyQuantifier(&cursor, &pq.nodes.items[root]);
            try applyCapture(gpa, &pq, &cursor, root);

            try collectTrailingPredicates(gpa, &pq, &cursor, &collector);

            try pq.patterns.append(gpa, .{
                .root = root,
                .predicates = try collector.preds.toOwnedSlice(gpa),
                .settings = try collector.settings.toOwnedSlice(gpa),
                .directives = try collector.directives.toOwnedSlice(gpa),
            });
        } else {
            return error.UnexpectedToken;
        }
    }
    if (pq.patterns.items.len == 0) return error.UnexpectedEof;
    linkChildren(gpa, &pq);
    try validateCaptures(&pq);
    return pq;
}

/// Every capture referenced by a predicate, setting, or directive must
/// be declared by a node pattern: typos fail at compile time instead of
/// silently matching nothing.
fn validateCaptures(pq: *const ParsedQuery) QueryParseError!void {
    for (pq.patterns.items) |pat| {
        for (pat.predicates) |pred| {
            for (pred.args) |arg| {
                switch (arg) {
                    .capture => |id| try checkDeclared(pq, id),
                    .literal => {},
                }
            }
        }
        for (pat.settings) |setting| {
            if (setting.capture) |id| try checkDeclared(pq, id);
        }
        for (pat.directives) |dir| {
            for (dir.args) |arg| {
                switch (arg) {
                    .capture => |id| try checkDeclared(pq, id),
                    .literal => {},
                }
            }
        }
    }
}

fn checkDeclared(pq: *const ParsedQuery, id: u32) QueryParseError!void {
    if (id >= pq.node_declared.items.len or !pq.node_declared.items[id]) {
        return error.InvalidCapture;
    }
}

fn isGroupStart(cursor: *Cursor) bool {
    const saved = cursor.pos;
    cursor.skipTrivia();
    if (cursor.pos >= cursor.text.len or cursor.text[cursor.pos] != '(') {
        cursor.pos = saved;
        return false;
    }
    var i = cursor.pos + 1;
    while (i < cursor.text.len and (cursor.text[i] == ' ' or cursor.text[i] == '\t' or
        cursor.text[i] == '\n' or cursor.text[i] == '\r' or cursor.text[i] == ';'))
    {
        if (cursor.text[i] == ';') {
            while (i < cursor.text.len and cursor.text[i] != '\n') : (i += 1) {}
        } else {
            i += 1;
        }
    }
    cursor.pos = saved;
    return i < cursor.text.len and cursor.text[i] == '(';
}

fn parseGroup(
    gpa: std.mem.Allocator,
    pq: *ParsedQuery,
    cursor: *Cursor,
    collector: *PatternCollector,
) QueryParseError!u32 {
    try cursor.expect('(');
    var root: ?u32 = null;
    while (true) {
        cursor.skipTrivia();
        if (cursor.eof()) return error.UnexpectedEof;
        // A `.` at group level has no sibling to anchor: vacuous.
        if (cursor.text[cursor.pos] == '.') {
            cursor.pos += 1;
            continue;
        }
        if (cursor.text[cursor.pos] == ')') {
            cursor.pos += 1;
            break;
        }
        if (cursor.text[cursor.pos] != '(') return error.UnexpectedToken;
        const saved = cursor.pos;
        cursor.pos += 1;
        cursor.skipTrivia();
        const is_pred = cursor.pos < cursor.text.len and cursor.text[cursor.pos] == '#';
        cursor.pos = saved;
        if (is_pred) {
            switch (try parsePredicate(gpa, pq, cursor)) {
                .pred => |pred| try collector.preds.append(gpa, pred),
                .setting => |setting| try collector.settings.append(gpa, setting),
                .general => |directive| try collector.directives.append(gpa, directive),
            }
        } else {
            if (root != null) return error.InvalidSyntax;
            root = try parseNode(gpa, pq, cursor, true, collector);
        }
    }
    return root orelse error.InvalidSyntax;
}

fn linkChildren(gpa: std.mem.Allocator, pq: *ParsedQuery) void {
    _ = gpa;
    for (pq.nodes.items, 0..) |*node, i| {
        node.children = pq.child_lists.items[i].items;
        node.child_fields = pq.field_lists.items[i].items;
        node.negated_fields = pq.negated_field_lists.items[i].items;
    }
}

fn captureIndex(gpa: std.mem.Allocator, pq: *ParsedQuery, name: []const u8) QueryParseError!u32 {
    for (pq.captures.items, 0..) |n, i| {
        if (std.mem.eql(u8, n, name)) return @as(u32, @intCast(i));
    }
    try pq.captures.append(gpa, name);
    return @as(u32, @intCast(pq.captures.items.len - 1));
}

/// Capture attached to a node pattern: declares the name for later
/// predicate/directive references (undeclared references produce
/// `InvalidCapture`).
fn declareCapture(gpa: std.mem.Allocator, pq: *ParsedQuery, name: []const u8) QueryParseError!u32 {
    const id = try captureIndex(gpa, pq, name);
    while (pq.node_declared.items.len <= id) try pq.node_declared.append(gpa, false);
    pq.node_declared.items[id] = true;
    return id;
}

fn allocNode(gpa: std.mem.Allocator, pq: *ParsedQuery) QueryParseError!u32 {
    const idx = pq.nodes.items.len;
    try pq.nodes.append(gpa, .{});
    try pq.child_lists.append(gpa, .empty);
    try pq.field_lists.append(gpa, .empty);
    try pq.negated_field_lists.append(gpa, .empty);
    return @as(u32, @intCast(idx));
}

fn parseNode(
    gpa: std.mem.Allocator,
    pq: *ParsedQuery,
    cursor: *Cursor,
    is_root: bool,
    collector: *PatternCollector,
) QueryParseError!u32 {
    _ = is_root;
    try cursor.expect('(');
    cursor.skipTrivia();
    const idx = try allocNode(gpa, pq);
    var node = &pq.nodes.items[idx];
    // A `.` before any child is a leading anchor; between children it
    // anchors the next child to its predecessor (anchors ignore anonymous nodes).
    var between_next = false;

    if (!cursor.eof() and cursor.text[cursor.pos] == '_') {
        cursor.pos += 1;
        node.kind = .wildcard;
        node.name = "_";
    } else if (!cursor.eof() and cursor.text[cursor.pos] == '"') {
        node.kind = .anonymous;
        node.name = try cursor.readString();
    } else {
        node.kind = .named;
        node.name = try cursor.readSymbol();
        if (std.mem.eql(u8, node.name, "_")) node.kind = .wildcard;
    }

    while (true) {
        cursor.skipTrivia();
        if (cursor.eof()) return error.UnexpectedEof;
        const c = cursor.text[cursor.pos];
        if (c == ')') {
            cursor.pos += 1;
            applyQuantifier(cursor, &pq.nodes.items[idx]);
            try applyCapture(gpa, pq, cursor, idx);
            return idx;
        } else if (c == '.') {
            cursor.pos += 1;
            cursor.skipTrivia();
            if (!cursor.eof() and cursor.text[cursor.pos] == ')') {
                pq.nodes.items[idx].anchor_after = true;
            } else if (pq.child_lists.items[idx].items.len == 0) {
                pq.nodes.items[idx].anchor_before = true;
            } else {
                between_next = true;
            }
        } else if (c == '(') {
            const saved = cursor.pos;
            cursor.pos += 1;
            cursor.skipTrivia();
            if (cursor.pos < cursor.text.len and cursor.text[cursor.pos] == '#') {
                cursor.pos = saved;
                switch (try parsePredicate(gpa, pq, cursor)) {
                    .pred => |pred| try collector.preds.append(gpa, pred),
                    .setting => |setting| try collector.settings.append(gpa, setting),
                    .general => |directive| try collector.directives.append(gpa, directive),
                }
                continue;
            }
            cursor.pos = saved;
            const child = try parseNode(gpa, pq, cursor, false, collector);
            try pq.child_lists.items[idx].append(gpa, child);
            try pq.field_lists.items[idx].append(gpa, null);
            if (between_next) {
                pq.nodes.items[child].anchor_before = true;
                between_next = false;
            }
            try applyCapture(gpa, pq, cursor, child);
        } else if (c == '"') {
            const child = try allocNode(gpa, pq);
            pq.nodes.items[child] = .{ .kind = .anonymous, .name = try cursor.readString() };
            try pq.child_lists.items[idx].append(gpa, child);
            try pq.field_lists.items[idx].append(gpa, null);
            if (between_next) {
                pq.nodes.items[child].anchor_before = true;
                between_next = false;
            }
            try applyCapture(gpa, pq, cursor, child);
        } else if (c == '[') {
            var alts = try parseAlternation(gpa, pq, cursor, collector);
            defer alts.deinit(gpa);
            for (alts.items) |child| {
                try pq.child_lists.items[idx].append(gpa, child);
                try pq.field_lists.items[idx].append(gpa, pq.nodes.items[child].field);
                if (between_next) {
                    pq.nodes.items[child].anchor_before = true;
                }
            }
            between_next = false;
        } else if (c == '@' or c == '#' or c == '!') {
            if (c == '!') {
                // Negated field assertion: the node must lack this field.
                cursor.pos += 1;
                const field = try cursor.readSymbol();
                try pq.negated_field_lists.items[idx].append(gpa, field);
                continue;
            }
            try cursor.expect(')');
            applyQuantifier(cursor, &pq.nodes.items[idx]);
            try applyCapture(gpa, pq, cursor, idx);
            return idx;
        } else {
            const word = try cursor.readSymbol();
            cursor.skipTrivia();
            if (!cursor.eof() and cursor.text[cursor.pos] == ':') {
                cursor.pos += 1;
                cursor.skipTrivia();
                if (cursor.eof()) return error.UnexpectedEof;
                const fc = cursor.text[cursor.pos];
                var child: u32 = 0;
                if (fc == '(') {
                    child = try parseNode(gpa, pq, cursor, false, collector);
                } else if (fc == '"') {
                    child = try allocNode(gpa, pq);
                    pq.nodes.items[child] = .{ .kind = .anonymous, .name = try cursor.readString() };
                } else if (fc == '[') {
                    var alts = try parseAlternation(gpa, pq, cursor, collector);
                    defer alts.deinit(gpa);
                    for (alts.items) |alt_child| {
                        pq.nodes.items[alt_child].field = word;
                        try pq.child_lists.items[idx].append(gpa, alt_child);
                        try pq.field_lists.items[idx].append(gpa, word);
                        if (between_next) {
                            pq.nodes.items[alt_child].anchor_before = true;
                        }
                    }
                    between_next = false;
                    continue;
                } else {
                    const sym = try cursor.readSymbol();
                    child = try allocNode(gpa, pq);
                    pq.nodes.items[child] = .{
                        .kind = if (std.mem.eql(u8, sym, "_")) .wildcard else .named,
                        .name = sym,
                    };
                }
                pq.nodes.items[child].field = word;
                try pq.child_lists.items[idx].append(gpa, child);
                try pq.field_lists.items[idx].append(gpa, word);
                if (between_next) {
                    pq.nodes.items[child].anchor_before = true;
                    between_next = false;
                }
                try applyCapture(gpa, pq, cursor, child);
            } else if (std.mem.eql(u8, word, "_")) {
                const child = try allocNode(gpa, pq);
                pq.nodes.items[child] = .{ .kind = .wildcard, .name = "_" };
                try pq.child_lists.items[idx].append(gpa, child);
                try pq.field_lists.items[idx].append(gpa, null);
                if (between_next) {
                    pq.nodes.items[child].anchor_before = true;
                    between_next = false;
                }
            } else {
                return error.InvalidSyntax;
            }
        }
    }
}

fn applyQuantifier(cursor: *Cursor, node: *pattern_mod.PatternNode) void {
    if (cursor.pos < cursor.text.len) {
        const c = cursor.text[cursor.pos];
        if (c == '?' or c == '*' or c == '+') {
            cursor.pos += 1;
            node.quantifier = switch (c) {
                '?' => .optional,
                '*' => .zero_or_more,
                else => .one_or_more,
            };
        }
    }
}

fn applyCapture(gpa: std.mem.Allocator, pq: *ParsedQuery, cursor: *Cursor, idx: u32) QueryParseError!void {
    while (true) {
        const saved = cursor.pos;
        cursor.skipTrivia();
        if (!cursor.eof() and cursor.text[cursor.pos] == '@') {
            const name = try cursor.readCaptureName();
            pq.nodes.items[idx].capture = try declareCapture(gpa, pq, name);
        } else if (!cursor.eof() and cursor.text[cursor.pos] == '!') {
            cursor.pos += 1;
            const field = try cursor.readSymbol();
            try pq.negated_field_lists.items[idx].append(gpa, field);
        } else {
            cursor.pos = saved;
            break;
        }
    }
}

fn parseAlternation(
    gpa: std.mem.Allocator,
    pq: *ParsedQuery,
    cursor: *Cursor,
    collector: *PatternCollector,
) QueryParseError!std.ArrayList(u32) {
    try cursor.expect('[');
    var alts = std.ArrayList(u32).empty;
    errdefer alts.deinit(gpa);

    while (true) {
        cursor.skipTrivia();
        if (cursor.eof()) return error.UnexpectedEof;
        const c = cursor.text[cursor.pos];
        if (c == ']') {
            cursor.pos += 1;
            break;
        } else if (c == '(') {
            const node = try parseNode(gpa, pq, cursor, false, collector);
            try alts.append(gpa, node);
        } else if (c == '"') {
            const node = try allocNode(gpa, pq);
            pq.nodes.items[node] = .{ .kind = .anonymous, .name = try cursor.readString() };
            applyQuantifier(cursor, &pq.nodes.items[node]);
            try applyCapture(gpa, pq, cursor, node);
            try alts.append(gpa, node);
        } else if (c == '[') {
            var inner_alts = try parseAlternation(gpa, pq, cursor, collector);
            defer inner_alts.deinit(gpa);
            for (inner_alts.items) |item| {
                try alts.append(gpa, item);
            }
        } else if (c == '_') {
            cursor.pos += 1;
            const node = try allocNode(gpa, pq);
            pq.nodes.items[node] = .{ .kind = .wildcard, .name = "_" };
            applyQuantifier(cursor, &pq.nodes.items[node]);
            try applyCapture(gpa, pq, cursor, node);
            try alts.append(gpa, node);
        } else {
            const sym = try cursor.readSymbol();
            cursor.skipTrivia();
            if (!cursor.eof() and cursor.text[cursor.pos] == ':') {
                cursor.pos += 1;
                cursor.skipTrivia();
                if (cursor.eof()) return error.UnexpectedEof;
                const fc = cursor.text[cursor.pos];
                var node: u32 = 0;
                if (fc == '(') {
                    node = try parseNode(gpa, pq, cursor, false, collector);
                } else if (fc == '"') {
                    node = try allocNode(gpa, pq);
                    pq.nodes.items[node] = .{ .kind = .anonymous, .name = try cursor.readString() };
                } else if (fc == '[') {
                    var inner_alts = try parseAlternation(gpa, pq, cursor, collector);
                    defer inner_alts.deinit(gpa);
                    for (inner_alts.items) |alt_child| {
                        pq.nodes.items[alt_child].field = sym;
                        try alts.append(gpa, alt_child);
                    }
                    continue;
                } else {
                    const inner_sym = try cursor.readSymbol();
                    node = try allocNode(gpa, pq);
                    pq.nodes.items[node] = .{
                        .kind = if (std.mem.eql(u8, inner_sym, "_")) .wildcard else .named,
                        .name = inner_sym,
                    };
                }
                pq.nodes.items[node].field = sym;
                applyQuantifier(cursor, &pq.nodes.items[node]);
                try applyCapture(gpa, pq, cursor, node);
                try alts.append(gpa, node);
                continue;
            }
            const node = try allocNode(gpa, pq);
            pq.nodes.items[node] = .{ .kind = .named, .name = sym };
            applyQuantifier(cursor, &pq.nodes.items[node]);
            try applyCapture(gpa, pq, cursor, node);
            try alts.append(gpa, node);
        }
    }

    if (alts.items.len == 0) return error.InvalidSyntax;

    // Optional quantifier on alternation
    cursor.skipTrivia();
    if (!cursor.eof()) {
        const qc = cursor.text[cursor.pos];
        if (qc == '?' or qc == '*' or qc == '+') {
            const quant: pattern_mod.Quantifier = switch (qc) {
                '?' => .optional,
                '*' => .zero_or_more,
                else => .one_or_more,
            };
            cursor.pos += 1;
            for (alts.items) |node_id| {
                pq.nodes.items[node_id].quantifier = quant;
            }
        }
    }

    // Optional capture on alternation
    cursor.skipTrivia();
    if (!cursor.eof() and cursor.text[cursor.pos] == '@') {
        const cap_name = try cursor.readCaptureName();
        const cap_id = try declareCapture(gpa, pq, cap_name);
        for (alts.items) |node_id| {
            pq.nodes.items[node_id].capture = cap_id;
        }
    }

    return alts;
}

/// One parsed `(#...)` item: an evaluated predicate, a `set!` property
/// setting, or a general directive for higher-level code.
pub const PredItem = union(enum) {
    pred: pattern_mod.Predicate,
    setting: pattern_mod.Setting,
    general: pattern_mod.Directive,
};

fn parsePredicate(gpa: std.mem.Allocator, pq: *ParsedQuery, cursor: *Cursor) QueryParseError!PredItem {
    try cursor.expect('(');
    cursor.skipTrivia();
    try cursor.expect('#');
    const name = try cursor.readSymbol();
    var args = std.ArrayList(pattern_mod.PredicateArg).empty;
    errdefer args.deinit(gpa);
    while (true) {
        cursor.skipTrivia();
        if (cursor.eof()) return error.UnexpectedEof;
        const c = cursor.text[cursor.pos];
        if (c == ')') {
            cursor.pos += 1;
            break;
        } else if (c == '@') {
            const cap = try cursor.readCaptureName();
            const id = try captureIndex(gpa, pq, cap);
            try args.append(gpa, .{ .capture = id });
        } else if (c == '"') {
            const lit = try cursor.readString();
            try args.append(gpa, .{ .literal = lit });
        } else {
            const word = try cursor.readSymbol();
            try args.append(gpa, .{ .literal = word });
        }
    }
    if (name.len > 0 and name[name.len - 1] == '!') {
        return parseDirective(name, args, gpa);
    }
    const kind = predicate_mod.predicateKindForName(name) orelse return error.InvalidPredicate;
    try validatePredicateArgs(kind, args.items);
    return .{ .pred = .{ .kind = kind, .name = name, .args = try args.toOwnedSlice(gpa) } };
}

/// Validate argument shapes: first arguments must be captures where the
/// operator compares capture text, `match?` takes a literal pattern, and
/// `any-of?` takes literals only.
fn validatePredicateArgs(kind: pattern_mod.PredicateKind, args: []const pattern_mod.PredicateArg) QueryParseError!void {
    switch (kind) {
        .eq, .not_eq, .any_eq, .any_not_eq => {
            if (args.len != 2) return error.InvalidPredicate;
            if (args[0] != .capture) return error.InvalidPredicate;
        },
        .match, .not_match, .any_match, .any_not_match => {
            if (args.len != 2) return error.InvalidPredicate;
            if (args[0] != .capture) return error.InvalidPredicate;
            if (args[1] != .literal) return error.InvalidPredicate;
        },
        .contains, .not_contains => {
            if (args.len != 2) return error.InvalidPredicate;
            if (args[0] != .capture) return error.InvalidPredicate;
        },
        .any_of, .not_any_of => {
            if (args.len < 1) return error.InvalidPredicate;
            if (args.len > 0 and args[0] != .capture) return error.InvalidPredicate;
            for (args[1..]) |arg| {
                if (arg != .literal) return error.InvalidPredicate;
            }
        },
        .is, .is_not => {
            if (args.len < 1 or args.len > 3) return error.InvalidPredicate;
        },
    }
}

/// `set!` becomes a property setting (1-3 args, at most one capture, key required);
/// every other `!` operator becomes a general directive for higher-level code.
fn parseDirective(
    name: []const u8,
    args: std.ArrayList(pattern_mod.PredicateArg),
    gpa: std.mem.Allocator,
) QueryParseError!PredItem {
    var owned = args;
    errdefer owned.deinit(gpa);
    if (std.mem.eql(u8, name, "set!")) {
        if (owned.items.len < 1 or owned.items.len > 3) return error.InvalidPredicate;
        var capture: ?u32 = null;
        var key: ?[]const u8 = null;
        var value: ?[]const u8 = null;
        for (owned.items) |arg| {
            switch (arg) {
                .capture => |id| {
                    if (capture != null) return error.InvalidPredicate;
                    capture = id;
                },
                .literal => |lit| {
                    if (key == null) {
                        key = lit;
                    } else if (value == null) {
                        value = lit;
                    } else {
                        return error.InvalidPredicate;
                    }
                },
            }
        }
        const k = key orelse return error.InvalidPredicate;
        // Setting borrows key/value slices from the query source; the
        // argument buffer itself is scratch.
        owned.deinit(gpa);
        return .{ .setting = .{ .key = k, .value = value, .capture = capture } };
    }
    return .{ .general = .{ .operator = name, .args = try owned.toOwnedSlice(gpa) } };
}
