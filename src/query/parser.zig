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
    /// a node pattern (mirrors upstream's undeclared-capture error).
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
            if (c == '(' or c == ')' or c == '"' or c == ';' or c == ' ' or
                c == '\t' or c == '\n' or c == '\r' or c == ':' or c == '@' or c == '#' or c == '.')
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
            const is_group = isGroupStart(&cursor);
            if (is_group) {
                const group = try parseGroup(gpa, &pq, &cursor);
                try pq.patterns.append(gpa, .{ .root = group.root, .predicates = group.predicates, .settings = group.settings, .directives = group.directives });
                continue;
            }
            const root = try parseNode(gpa, &pq, &cursor, true);
            var preds = std.ArrayList(pattern_mod.Predicate).empty;
            errdefer preds.deinit(gpa);
            var settings = std.ArrayList(pattern_mod.Setting).empty;
            errdefer settings.deinit(gpa);
            var directives = std.ArrayList(pattern_mod.Directive).empty;
            errdefer directives.deinit(gpa);
            while (true) {
                cursor.skipTrivia();
                if (cursor.eof() or cursor.text[cursor.pos] != '(') break;
                const saved = cursor.pos;
                cursor.pos += 1;
                cursor.skipTrivia();
                if (cursor.pos < cursor.text.len and cursor.text[cursor.pos] == '#') {
                    cursor.pos = saved;
                    switch (try parsePredicate(gpa, &pq, &cursor)) {
                        .pred => |pred| try preds.append(gpa, pred),
                        .setting => |setting| try settings.append(gpa, setting),
                        .general => |directive| try directives.append(gpa, directive),
                    }
                } else {
                    cursor.pos = saved;
                    break;
                }
            }
            try pq.patterns.append(gpa, .{
                .root = root,
                .predicates = try preds.toOwnedSlice(gpa),
                .settings = try settings.toOwnedSlice(gpa),
                .directives = try directives.toOwnedSlice(gpa),
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
/// be declared by a node pattern (upstream parity: typos fail at
/// compile time instead of silently matching nothing).
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

const GroupResult = struct {
    root: u32,
    predicates: []pattern_mod.Predicate,
    settings: []pattern_mod.Setting,
    directives: []pattern_mod.Directive,
};

fn parseGroup(gpa: std.mem.Allocator, pq: *ParsedQuery, cursor: *Cursor) QueryParseError!GroupResult {
    try cursor.expect('(');
    var root: ?u32 = null;
    var preds = std.ArrayList(pattern_mod.Predicate).empty;
    errdefer preds.deinit(gpa);
    var settings = std.ArrayList(pattern_mod.Setting).empty;
    errdefer settings.deinit(gpa);
    var directives = std.ArrayList(pattern_mod.Directive).empty;
    errdefer directives.deinit(gpa);
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
                .pred => |pred| try preds.append(gpa, pred),
                .setting => |setting| try settings.append(gpa, setting),
                .general => |directive| try directives.append(gpa, directive),
            }
        } else {
            if (root != null) return error.InvalidSyntax;
            root = try parseNode(gpa, pq, cursor, true);
        }
    }
    const r = root orelse return error.InvalidSyntax;
    return .{
        .root = r,
        .predicates = try preds.toOwnedSlice(gpa),
        .settings = try settings.toOwnedSlice(gpa),
        .directives = try directives.toOwnedSlice(gpa),
    };
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
/// predicate/directive references (undeclared references are
/// `InvalidCapture`, mirroring upstream).
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

fn parseNode(gpa: std.mem.Allocator, pq: *ParsedQuery, cursor: *Cursor, is_root: bool) QueryParseError!u32 {
    _ = is_root;
    try cursor.expect('(');
    cursor.skipTrivia();
    const idx = try allocNode(gpa, pq);
    var node = &pq.nodes.items[idx];
    // A `.` before any child is a leading anchor; between children it
    // anchors the next child to its predecessor (both audited against
    // upstream: anchors ignore anonymous nodes).
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
            const child = try parseNode(gpa, pq, cursor, false);
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
                    child = try parseNode(gpa, pq, cursor, false);
                } else if (fc == '"') {
                    child = try allocNode(gpa, pq);
                    pq.nodes.items[child] = .{ .kind = .anonymous, .name = try cursor.readString() };
                } else {
                    return error.InvalidSyntax;
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

/// Argument shapes mirror the upstream binding: first arguments must
/// be captures where the operator compares capture text, `match?`
/// takes a literal pattern, and `any-of?` takes literals only.
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

/// `set!` becomes a property setting (upstream `parse_property`
/// rules: 1-3 args, at most one capture, key required); every other
/// `!` operator becomes a general directive for higher-level code.
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
