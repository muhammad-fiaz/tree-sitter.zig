const std = @import("std");

pub const compiler = @import("compiler.zig");
pub const GrammarCompiler = compiler.GrammarCompiler;
pub const dsl = @import("dsl.zig");
pub const DSLParser = dsl.DSLParser;

pub const Associativity = enum {
    none,
    left,
    right,
};

pub const Precedence = union(enum) {
    none,
    integer: i32,
    name: []const u8,
};

pub const RuleTag = enum {
    blank,
    eof,
    string,
    pattern,
    symbol,
    choice,
    seq,
    repeat,
    repeat1,
    optional,
    field,
    alias,
    prec,
    prec_left,
    prec_right,
    prec_dynamic,
    token,
    immediate_token,
};

pub const Rule = struct {
    tag: RuleTag,
    value: ?[]const u8 = null,
    integer_val: i32 = 0,
    named: bool = true,
    is_owned: bool = false,
    children: []const Rule = &.{},
    associativity: Associativity = .none,

    pub fn blank() Rule {
        return .{ .tag = .blank };
    }

    pub fn eof() Rule {
        return .{ .tag = .eof };
    }

    pub fn str(val: []const u8) Rule {
        return .{ .tag = .string, .value = val };
    }

    pub fn pattern(val: []const u8) Rule {
        return .{ .tag = .pattern, .value = val };
    }

    pub fn sym(name: []const u8) Rule {
        return .{ .tag = .symbol, .value = name };
    }

    pub fn choice(children: []const Rule) Rule {
        return .{ .tag = .choice, .children = children };
    }

    pub fn seq(children: []const Rule) Rule {
        return .{ .tag = .seq, .children = children };
    }

    pub fn repeat(child: Rule, gpa: std.mem.Allocator) !Rule {
        const slice = try gpa.alloc(Rule, 1);
        slice[0] = child;
        return .{ .tag = .repeat, .children = slice, .is_owned = true };
    }

    pub fn repeat1(child: Rule, gpa: std.mem.Allocator) !Rule {
        const slice = try gpa.alloc(Rule, 1);
        slice[0] = child;
        return .{ .tag = .repeat1, .children = slice, .is_owned = true };
    }

    pub fn optional(child: Rule, gpa: std.mem.Allocator) !Rule {
        const slice = try gpa.alloc(Rule, 1);
        slice[0] = child;
        return .{ .tag = .optional, .children = slice, .is_owned = true };
    }

    pub fn field(name: []const u8, child: Rule, gpa: std.mem.Allocator) !Rule {
        const slice = try gpa.alloc(Rule, 1);
        slice[0] = child;
        return .{ .tag = .field, .value = name, .children = slice, .is_owned = true };
    }

    pub fn alias(val: []const u8, is_named: bool, child: Rule, gpa: std.mem.Allocator) !Rule {
        const slice = try gpa.alloc(Rule, 1);
        slice[0] = child;
        return .{ .tag = .alias, .value = val, .named = is_named, .children = slice, .is_owned = true };
    }

    pub fn prec(val: i32, child: Rule, gpa: std.mem.Allocator) !Rule {
        const slice = try gpa.alloc(Rule, 1);
        slice[0] = child;
        return .{ .tag = .prec, .integer_val = val, .children = slice, .is_owned = true };
    }

    pub fn precLeft(val: i32, child: Rule, gpa: std.mem.Allocator) !Rule {
        const slice = try gpa.alloc(Rule, 1);
        slice[0] = child;
        return .{ .tag = .prec_left, .integer_val = val, .associativity = .left, .children = slice, .is_owned = true };
    }

    pub fn precRight(val: i32, child: Rule, gpa: std.mem.Allocator) !Rule {
        const slice = try gpa.alloc(Rule, 1);
        slice[0] = child;
        return .{ .tag = .prec_right, .integer_val = val, .associativity = .right, .children = slice, .is_owned = true };
    }

    pub fn token(child: Rule, gpa: std.mem.Allocator) !Rule {
        const slice = try gpa.alloc(Rule, 1);
        slice[0] = child;
        return .{ .tag = .token, .children = slice, .is_owned = true };
    }

    pub fn deinit(self: *Rule, allocator: std.mem.Allocator) void {
        for (self.children) |*c| {
            var mut_c = c.*;
            mut_c.deinit(allocator);
        }
        if (self.is_owned) {
            if (self.value) |v| allocator.free(v);
            if (self.children.len > 0) allocator.free(self.children);
        }
    }
};

pub const Variable = struct {
    name: []const u8,
    rule: Rule,
};

pub const Grammar = struct {
    name: []const u8,
    rules: std.ArrayList(Variable),
    extras: std.ArrayList(Rule),
    externals: std.ArrayList(Rule),
    conflicts: std.ArrayList([]const []const u8),
    inline_rules: std.ArrayList([]const u8),
    supertypes: std.ArrayList([]const u8),
    word: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !Grammar {
        return .{
            .name = try allocator.dupe(u8, name),
            .rules = std.ArrayList(Variable).empty,
            .extras = std.ArrayList(Rule).empty,
            .externals = std.ArrayList(Rule).empty,
            .conflicts = std.ArrayList([]const []const u8).empty,
            .inline_rules = std.ArrayList([]const u8).empty,
            .supertypes = std.ArrayList([]const u8).empty,
        };
    }

    pub fn deinit(self: *Grammar, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.rules.items) |*v| {
            allocator.free(v.name);
            v.rule.deinit(allocator);
        }
        self.rules.deinit(allocator);
        for (self.extras.items) |*e| e.deinit(allocator);
        self.extras.deinit(allocator);
        for (self.externals.items) |*ext| ext.deinit(allocator);
        self.externals.deinit(allocator);
        for (self.conflicts.items) |c| {
            for (c) |s| allocator.free(s);
            allocator.free(c);
        }
        self.conflicts.deinit(allocator);
        for (self.inline_rules.items) |i| allocator.free(i);
        self.inline_rules.deinit(allocator);
        for (self.supertypes.items) |s| allocator.free(s);
        self.supertypes.deinit(allocator);
        if (self.word) |w| allocator.free(w);
    }

    pub fn addRule(self: *Grammar, allocator: std.mem.Allocator, name: []const u8, rule: Rule) !void {
        try self.rules.append(allocator, .{ .name = try allocator.dupe(u8, name), .rule = rule });
    }

    pub fn addExtra(self: *Grammar, allocator: std.mem.Allocator, rule: Rule) !void {
        try self.extras.append(allocator, rule);
    }

    pub fn addExternal(self: *Grammar, allocator: std.mem.Allocator, rule: Rule) !void {
        try self.externals.append(allocator, rule);
    }
};

test "grammar: construct rule tree" {
    const r1 = Rule.str("+");
    try std.testing.expectEqual(RuleTag.string, r1.tag);
    try std.testing.expectEqualStrings("+", r1.value.?);

    const r_seq = Rule.seq(&.{ Rule.sym("expr"), r1, Rule.sym("expr") });
    try std.testing.expectEqual(RuleTag.seq, r_seq.tag);
    try std.testing.expectEqual(@as(usize, 3), r_seq.children.len);
}
