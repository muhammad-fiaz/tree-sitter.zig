const std = @import("std");
const pattern_mod = @import("pattern.zig");
const capture_mod = @import("capture.zig");
const node_mod = @import("../tree/node.zig");

const CharClass = struct { neg: bool, chars: []const u8 };

fn regexMatch(pattern: []const u8, text: []const u8) bool {
    return matchHere(pattern, text, 0, 0, false);
}

fn matchHere(pat: []const u8, text: []const u8, pi: usize, ti: usize, anchored_start: bool) bool {
    _ = anchored_start;
    var p = pi;
    const t = ti;
    if (p < pat.len and pat[p] == '^') {
        if (ti != 0) return false;
        p += 1;
    }
    return matchSeq(pat, text, p, t);
}

fn matchSeq(pat: []const u8, text: []const u8, pi: usize, ti: usize) bool {
    const p = pi;
    const t = ti;
    while (true) {
        var end_anchor = false;
        if (p < pat.len and pat[p] == '$' and p + 1 == pat.len) end_anchor = true;
        if (p >= pat.len) return if (end_anchor) t >= text.len else true;
        if (end_anchor) return t >= text.len;
        const c = pat[p];
        var min: usize = 1;
        var max: usize = 1;
        var atom_len: usize = 1;
        var cls: ?CharClass = null;
        if (c == '\\' and p + 1 < pat.len) {
            // Escaped literal: `\[`, `\\.`, `\?`, and friends match
            // themselves (routed through a class so `\.` is not a
            // wildcard). A trailing lone backslash stays literal.
            cls = .{ .neg = false, .chars = pat[p + 1 .. p + 2] };
            atom_len = 2;
        } else if (c == '[') {
            const close = std.mem.indexOfScalarPos(u8, pat, p, ']') orelse return false;
            var chars = pat[p + 1 .. close];
            var neg = false;
            if (chars.len > 0 and chars[0] == '^') {
                neg = true;
                chars = chars[1..];
            }
            cls = .{ .neg = neg, .chars = chars };
            atom_len = close - p + 1;
        }
        if (p + atom_len < pat.len and (pat[p + atom_len] == '*' or pat[p + atom_len] == '+' or pat[p + atom_len] == '?')) {
            const q = pat[p + atom_len];
            if (q == '*') {
                min = 0;
                max = std.math.maxInt(usize);
            } else if (q == '+') {
                min = 1;
                max = std.math.maxInt(usize);
            } else {
                min = 0;
                max = 1;
            }
            atom_len += 1;
        }
        var count: usize = 0;
        while (count < max and t + count < text.len and atomMatches(c, cls, text[t + count])) : (count += 1) {}
        if (count < min) return false;
        var try_count = count;
        while (true) {
            if (matchSeq(pat, text, p + atom_len, t + try_count)) return true;
            if (try_count == min or try_count == 0) break;
            try_count -= 1;
        }
        return false;
    }
}

fn atomMatches(c: u8, cls: ?CharClass, b: u8) bool {
    if (cls) |cl| {
        const hit = charInClass(cl.chars, b);
        return if (cl.neg) !hit else hit;
    }
    if (c == '.') return true;
    return c == b;
}

fn charInClass(chars: []const u8, b: u8) bool {
    var i: usize = 0;
    while (i < chars.len) {
        if (i + 2 < chars.len and chars[i + 1] == '-') {
            if (chars[i] <= b and b <= chars[i + 2]) return true;
            i += 3;
        } else {
            if (chars[i] == b) return true;
            i += 1;
        }
    }
    return false;
}

/// End offset (exclusive) of a greedy leftmost match starting exactly
/// at `ti`, or null. Mirrors `matchSeq` atom handling so spans agree
/// with boolean matching; powers `stripText` in `directives.zig`.
pub fn matchEndAt(pat: []const u8, text: []const u8, ti: usize) ?usize {
    var p: usize = 0;
    if (p < pat.len and pat[p] == '^') {
        if (ti != 0) return null;
        p += 1;
    }
    return seqEnd(pat, text, p, ti);
}

fn seqEnd(pat: []const u8, text: []const u8, pi: usize, ti: usize) ?usize {
    var p = pi;
    var t = ti;
    while (true) {
        if (p < pat.len and pat[p] == '$' and p + 1 == pat.len) {
            return if (t >= text.len) t else null;
        }
        if (p >= pat.len) return t;
        const c = pat[p];
        var min: usize = 1;
        var max: usize = 1;
        var atom_len: usize = 1;
        var cls: ?CharClass = null;
        if (c == '\\' and p + 1 < pat.len) {
            cls = .{ .neg = false, .chars = pat[p + 1 .. p + 2] };
            atom_len = 2;
        } else if (c == '[') {
            const close = std.mem.indexOfScalarPos(u8, pat, p, ']') orelse return null;
            var chars = pat[p + 1 .. close];
            var neg = false;
            if (chars.len > 0 and chars[0] == '^') {
                neg = true;
                chars = chars[1..];
            }
            cls = .{ .neg = neg, .chars = chars };
            atom_len = close - p + 1;
        }
        var quantified = false;
        if (p + atom_len < pat.len and (pat[p + atom_len] == '*' or pat[p + atom_len] == '+' or pat[p + atom_len] == '?')) {
            const q = pat[p + atom_len];
            if (q == '*') {
                min = 0;
                max = std.math.maxInt(usize);
            } else if (q == '+') {
                min = 1;
                max = std.math.maxInt(usize);
            } else {
                min = 0;
                max = 1;
            }
            atom_len += 1;
            quantified = true;
        }
        var count: usize = 0;
        while (count < max and t + count < text.len and atomMatches(c, cls, text[t + count])) : (count += 1) {}
        if (count < min) return null;
        if (quantified) {
            var try_count = count;
            while (true) {
                if (seqEnd(pat, text, p + atom_len, t + try_count)) |end| return end;
                if (try_count == min or try_count == 0) break;
                try_count -= 1;
            }
            return null;
        }
        t += count;
        p += atom_len;
    }
}

/// Leftmost match span at or after `from`, honoring `^`/`$`.
pub fn findSpan(pat: []const u8, text: []const u8, from: usize) ?[2]usize {
    var s = @min(from, text.len);
    if (pat.len > 0 and pat[0] == '^') {
        if (s != 0) return null;
        const end = matchEndAt(pat, text, 0) orelse return null;
        return .{ 0, end };
    }
    while (s <= text.len) : (s += 1) {
        if (s == text.len) {
            if (matchEndAt(pat, text, s)) |end| return .{ s, end };
            return null;
        }
        if (matchEndAt(pat, text, s)) |end| return .{ s, end };
    }
    return null;
}

pub fn evaluatePredicate(
    pred: pattern_mod.Predicate,
    captures: []const capture_mod.Capture,
) bool {
    switch (pred.kind) {
        .eq, .not_eq, .any_eq, .any_not_eq => {
            if (pred.args.len != 2) return true;
            const id = switch (pred.args[0]) {
                .capture => |c| c,
                else => return true,
            };
            const other = resolveArg(pred.args[1], captures) orelse return true;
            const match_all = pred.kind == .eq or pred.kind == .not_eq;
            const positive = pred.kind == .eq or pred.kind == .any_eq;
            var seen = false;
            var ok = match_all;
            for (captures) |c| {
                if (c.name_index != id) continue;
                seen = true;
                const hit = std.mem.eql(u8, c.node.text(), other);
                if (match_all) {
                    if (hit != positive) return false;
                } else {
                    if (hit == positive) return true;
                    ok = false;
                }
            }
            if (!seen) return true;
            return if (match_all) true else ok;
        },
        .match, .not_match, .any_match, .any_not_match => {
            if (pred.args.len != 2) return true;
            const id = switch (pred.args[0]) {
                .capture => |c| c,
                else => return true,
            };
            const rx = switch (pred.args[1]) {
                .literal => |lit| lit,
                else => return true,
            };
            const match_all = pred.kind == .match or pred.kind == .not_match;
            const positive = pred.kind == .match or pred.kind == .any_match;
            var seen = false;
            for (captures) |c| {
                if (c.name_index != id) continue;
                seen = true;
                const hit = regexMatch(rx, c.node.text());
                if (match_all) {
                    if (hit != positive) return false;
                } else if (hit == positive) {
                    return true;
                }
            }
            if (!seen) return true;
            return match_all;
        },
        .contains, .not_contains => {
            if (pred.args.len != 2) return true;
            const id = switch (pred.args[0]) {
                .capture => |c| c,
                else => return true,
            };
            const sub = resolveArg(pred.args[1], captures) orelse return true;
            // Extension (upstream leaves `contains?` to higher-level
            // code): every captured node must contain the substring.
            for (captures) |c| {
                if (c.name_index != id) continue;
                const hit = std.mem.indexOf(u8, c.node.text(), sub) != null;
                const want = pred.kind == .contains;
                if (hit != want) return false;
            }
            return true;
        },
        .is, .is_not => {
            if (pred.args.len != 2) return true;
            const id = switch (pred.args[0]) {
                .capture => |c| c,
                else => return true,
            };
            const prop = switch (pred.args[1]) {
                .literal => |lit| lit,
                else => return true,
            };
            // Structural extension: every captured node must satisfy
            // the property (unknown properties stay permissive).
            for (captures) |c| {
                if (c.name_index != id) continue;
                const hit = checkProperty(prop, c.node);
                const want = pred.kind == .is;
                if (hit != want) return false;
            }
            return true;
        },
        .any_of, .not_any_of => {
            if (pred.args.len < 1) return true;
            const id = switch (pred.args[0]) {
                .capture => |c| c,
                else => return true,
            };
            // Membership across every node carrying the capture: any
            // node matching any literal satisfies (empty value lists
            // match nothing, mirroring upstream).
            var hit = false;
            for (captures) |c| {
                if (c.name_index != id) continue;
                const text = c.node.text();
                for (pred.args[1..]) |arg| {
                    const lit = switch (arg) {
                        .literal => |l| l,
                        else => continue,
                    };
                    if (std.mem.eql(u8, text, lit)) {
                        hit = true;
                        break;
                    }
                }
                if (hit) break;
            }
            return if (pred.kind == .any_of) hit else !hit;
        },
    }
}

/// Node properties understood by `#is?` / `#is-not?`.
///
/// Recognized names: `named`, `anonymous`, `missing`, `error`
/// (an ERROR node or a subtree containing one), `extra`, and
/// `visible`. Unknown properties are reserved for host-defined
/// extensions and evaluate permissively (they never filter a match).
pub fn checkProperty(prop: []const u8, node: node_mod.Node) bool {
    if (std.mem.eql(u8, prop, "named")) return node.isNamed();
    if (std.mem.eql(u8, prop, "anonymous")) return !node.isNamed();
    if (std.mem.eql(u8, prop, "missing")) return node.isMissing();
    if (std.mem.eql(u8, prop, "error")) return node.isError() or node.hasError();
    if (std.mem.eql(u8, prop, "extra")) return node.isExtra();
    if (std.mem.eql(u8, prop, "visible")) return node.raw().visible;
    return true;
}

fn resolveArg(arg: pattern_mod.PredicateArg, captures: []const capture_mod.Capture) ?[]const u8 {
    switch (arg) {
        .literal => |lit| return lit,
        .capture => |id| {
            for (captures) |c| {
                if (c.name_index == id) return c.node.text();
            }
            return null;
        },
    }
}

pub fn predicateKindForName(name: []const u8) ?pattern_mod.PredicateKind {
    if (std.mem.eql(u8, name, "eq?")) return .eq;
    if (std.mem.eql(u8, name, "not-eq?")) return .not_eq;
    if (std.mem.eql(u8, name, "any-eq?")) return .any_eq;
    if (std.mem.eql(u8, name, "any-not-eq?")) return .any_not_eq;
    if (std.mem.eql(u8, name, "match?")) return .match;
    if (std.mem.eql(u8, name, "not-match?")) return .not_match;
    if (std.mem.eql(u8, name, "any-match?")) return .any_match;
    if (std.mem.eql(u8, name, "any-not-match?")) return .any_not_match;
    if (std.mem.eql(u8, name, "contains?")) return .contains;
    if (std.mem.eql(u8, name, "not-contains?")) return .not_contains;
    if (std.mem.eql(u8, name, "is?")) return .is;
    if (std.mem.eql(u8, name, "is-not?")) return .is_not;
    if (std.mem.eql(u8, name, "any-of?")) return .any_of;
    if (std.mem.eql(u8, name, "not-any-of?")) return .not_any_of;
    return null;
}

// (The tree is assembled directly so these tests need no parser.)

const tree_mod = @import("../tree/tree.zig");
const subtree_mod = @import("../tree/subtree.zig");
const language_mod = @import("../language/language.zig");

fn testTree() !tree_mod.Tree {
    var pool = subtree_mod.SubtreePool{};
    errdefer pool.deinit(std.testing.allocator);
    const idx = try pool.pushNode(std.testing.allocator, .{
        .symbol = 1,
        .start_byte = 0,
        .end_byte = 3,
        .start_point = .{},
        .end_point = .{ .row = 0, .column = 3 },
        .named = true,
        .visible = true,
    });
    const source = try std.testing.allocator.dupe(u8, "foo");
    return .{
        .gpa = std.testing.allocator,
        .language = language_mod.expression_language,
        .source = source,
        .pool = pool,
        .root_index = idx,
    };
}

fn eval(kind: pattern_mod.PredicateKind, args: []pattern_mod.PredicateArg, node: node_mod.Node) bool {
    const caps = [_]capture_mod.Capture{.{ .name = "x", .name_index = 0, .node = node }};
    return evaluatePredicate(.{ .kind = kind, .name = "test", .args = args }, &caps);
}

test "predicate: eq and match" {
    var tree = try testTree();
    defer tree.deinit();
    const node = tree.rootNode();
    var a1 = [_]pattern_mod.PredicateArg{ .{ .capture = 0 }, .{ .literal = "foo" } };
    try std.testing.expect(eval(.eq, &a1, node));
    var a2 = [_]pattern_mod.PredicateArg{ .{ .capture = 0 }, .{ .literal = "bar" } };
    try std.testing.expect(!eval(.eq, &a2, node));
    try std.testing.expect(eval(.not_eq, &a2, node));
    var a3 = [_]pattern_mod.PredicateArg{ .{ .capture = 0 }, .{ .literal = "^f" } };
    try std.testing.expect(eval(.match, &a3, node));
    var a4 = [_]pattern_mod.PredicateArg{ .{ .capture = 0 }, .{ .literal = "^z" } };
    try std.testing.expect(!eval(.match, &a4, node));
    try std.testing.expect(eval(.not_match, &a4, node));
    var a5 = [_]pattern_mod.PredicateArg{ .{ .capture = 0 }, .{ .literal = "oo" } };
    try std.testing.expect(eval(.contains, &a5, node));
    try std.testing.expect(!eval(.not_contains, &a5, node));
}

test "predicate: any-of membership" {
    var tree = try testTree();
    defer tree.deinit();
    const node = tree.rootNode();
    var hit = [_]pattern_mod.PredicateArg{ .{ .capture = 0 }, .{ .literal = "a" }, .{ .literal = "foo" } };
    try std.testing.expect(eval(.any_of, &hit, node));
    try std.testing.expect(!eval(.not_any_of, &hit, node));
    var miss = [_]pattern_mod.PredicateArg{ .{ .capture = 0 }, .{ .literal = "a" }, .{ .literal = "b" } };
    try std.testing.expect(!eval(.any_of, &miss, node));
    try std.testing.expect(eval(.not_any_of, &miss, node));
}

test "predicate: is property checks" {
    var tree = try testTree();
    defer tree.deinit();
    const node = tree.rootNode();
    var named = [_]pattern_mod.PredicateArg{ .{ .capture = 0 }, .{ .literal = "named" } };
    try std.testing.expect(eval(.is, &named, node));
    try std.testing.expect(!eval(.is_not, &named, node));
    var anon = [_]pattern_mod.PredicateArg{ .{ .capture = 0 }, .{ .literal = "anonymous" } };
    try std.testing.expect(!eval(.is, &anon, node));
    try std.testing.expect(eval(.is_not, &anon, node));
    var missing = [_]pattern_mod.PredicateArg{ .{ .capture = 0 }, .{ .literal = "missing" } };
    try std.testing.expect(!eval(.is, &missing, node));
    var extra = [_]pattern_mod.PredicateArg{ .{ .capture = 0 }, .{ .literal = "extra" } };
    try std.testing.expect(!eval(.is, &extra, node));
    var visible = [_]pattern_mod.PredicateArg{ .{ .capture = 0 }, .{ .literal = "visible" } };
    try std.testing.expect(eval(.is, &visible, node));
    // Unknown properties are reserved: they never filter a match.
    var custom = [_]pattern_mod.PredicateArg{ .{ .capture = 0 }, .{ .literal = "local" } };
    try std.testing.expect(eval(.is, &custom, node));
}

test "predicate: names resolve" {
    try std.testing.expectEqual(pattern_mod.PredicateKind.any_of, predicateKindForName("any-of?").?);
    try std.testing.expectEqual(pattern_mod.PredicateKind.not_any_of, predicateKindForName("not-any-of?").?);
    try std.testing.expectEqual(pattern_mod.PredicateKind.is, predicateKindForName("is?").?);
    try std.testing.expectEqual(pattern_mod.PredicateKind.is_not, predicateKindForName("is-not?").?);
    try std.testing.expect(predicateKindForName("bogus?") == null);
}
