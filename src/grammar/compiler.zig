const std = @import("std");
const grammar_mod = @import("ast.zig");
const Grammar = grammar_mod.Grammar;
const Rule = grammar_mod.Rule;
const RuleTag = grammar_mod.RuleTag;

pub const ValidationError = error{
    EmptyGrammar,
    MissingEntryRule,
    UndefinedSymbol,
    CircularInlineRule,
    DuplicateRuleName,
};

pub const CompileDiagnostic = struct {
    message: []const u8,
    is_error: bool = false,
};

pub const FirstFollowSets = struct {
    allocator: std.mem.Allocator,
    // Symbol name -> set of terminal names in FIRST set
    first: std.StringHashMap(std.StringHashMap(void)),
    // Symbol name -> set of terminal names in FOLLOW set
    follow: std.StringHashMap(std.StringHashMap(void)),
    // Symbol name -> boolean indicating if it can derive empty string
    nullable: std.StringHashMap(bool),

    pub fn init(allocator: std.mem.Allocator) FirstFollowSets {
        return .{
            .allocator = allocator,
            .first = std.StringHashMap(std.StringHashMap(void)).init(allocator),
            .follow = std.StringHashMap(std.StringHashMap(void)).init(allocator),
            .nullable = std.StringHashMap(bool).init(allocator),
        };
    }

    pub fn deinit(self: *FirstFollowSets) void {
        var it_first = self.first.iterator();
        while (it_first.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.first.deinit();

        var it_follow = self.follow.iterator();
        while (it_follow.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.follow.deinit();

        self.nullable.deinit();
    }
};

pub const GrammarCompiler = struct {
    allocator: std.mem.Allocator,
    grammar: *const Grammar,
    diagnostics: std.ArrayList(CompileDiagnostic),

    pub fn init(allocator: std.mem.Allocator, grammar: *const Grammar) GrammarCompiler {
        return .{
            .allocator = allocator,
            .grammar = grammar,
            .diagnostics = std.ArrayList(CompileDiagnostic).empty,
        };
    }

    pub fn deinit(self: *GrammarCompiler) void {
        const gpa = self.allocator;
        for (self.diagnostics.items) |d| gpa.free(d.message);
        self.diagnostics.deinit(gpa);
    }

    /// Validate grammar rules, symbols, and references
    pub fn validate(self: *GrammarCompiler) !void {
        const gpa = self.allocator;

        if (self.grammar.rules.items.len == 0) {
            try self.diagnostics.append(gpa, .{
                .message = try gpa.dupe(u8, "Grammar has no rules defined"),
                .is_error = true,
            });
            return error.EmptyGrammar;
        }

        // Rule names map to detect duplicates
        var defined_rules = std.StringHashMap(void).init(gpa);
        defer defined_rules.deinit();

        for (self.grammar.rules.items) |v| {
            if (defined_rules.contains(v.name)) {
                const msg = try std.fmt.allocPrint(gpa, "Duplicate rule definition: '{s}'", .{v.name});
                try self.diagnostics.append(gpa, .{ .message = msg, .is_error = true });
                return error.DuplicateRuleName;
            }
            try defined_rules.put(v.name, {});
        }

        // Validate references inside each rule
        for (self.grammar.rules.items) |v| {
            try self.validateRuleReferences(v.rule, &defined_rules);
        }
    }

    fn validateRuleReferences(self: *GrammarCompiler, rule: Rule, defined_rules: *const std.StringHashMap(void)) !void {
        const gpa = self.allocator;
        switch (rule.tag) {
            .symbol => {
                if (rule.value) |sym_name| {
                    if (!defined_rules.contains(sym_name)) {
                        // Check if it's an external
                        var is_external = false;
                        for (self.grammar.externals.items) |ext| {
                            if (ext.value) |eval| {
                                if (std.mem.eql(u8, eval, sym_name)) {
                                    is_external = true;
                                    break;
                                }
                            }
                        }
                        if (!is_external) {
                            const msg = try std.fmt.allocPrint(gpa, "Undefined symbol reference: '{s}'", .{sym_name});
                            try self.diagnostics.append(gpa, .{ .message = msg, .is_error = true });
                            return error.UndefinedSymbol;
                        }
                    }
                }
            },
            .choice, .seq => {
                for (rule.children) |c| {
                    try self.validateRuleReferences(c, defined_rules);
                }
            },
            .repeat, .repeat1, .optional, .field, .alias, .prec, .prec_left, .prec_right, .token, .immediate_token => {
                for (rule.children) |c| {
                    try self.validateRuleReferences(c, defined_rules);
                }
            },
            else => {},
        }
    }

    /// Compute nullable rules and FIRST / FOLLOW sets
    pub fn computeFirstFollow(self: *GrammarCompiler) !FirstFollowSets {
        const gpa = self.allocator;
        var sets = FirstFollowSets.init(gpa);
        errdefer sets.deinit();

        // Initialize entries
        for (self.grammar.rules.items) |v| {
            try sets.first.put(v.name, std.StringHashMap(void).init(gpa));
            try sets.follow.put(v.name, std.StringHashMap(void).init(gpa));
            try sets.nullable.put(v.name, false);
        }

        // Iterative fixed-point computation for nullable & FIRST sets
        var changed = true;
        while (changed) {
            changed = false;
            for (self.grammar.rules.items) |v| {
                const is_null = self.checkNullable(v.rule, &sets.nullable);
                if (is_null != sets.nullable.get(v.name).?) {
                    try sets.nullable.put(v.name, is_null);
                    changed = true;
                }

                var first_set = sets.first.getPtr(v.name).?;
                const prev_count = first_set.count();
                try self.collectFirst(v.rule, first_set, &sets);
                if (first_set.count() != prev_count) {
                    changed = true;
                }
            }
        }

        // Add 'end' token to entry rule's FOLLOW set
        if (self.grammar.rules.items.len > 0) {
            const entry_name = self.grammar.rules.items[0].name;
            if (sets.follow.getPtr(entry_name)) |follow_set| {
                try follow_set.put("end", {});
            }
        }

        return sets;
    }

    fn checkNullable(self: *GrammarCompiler, rule: Rule, nullable_map: *const std.StringHashMap(bool)) bool {
        switch (rule.tag) {
            .blank, .optional, .repeat => return true,
            .string, .pattern => return false,
            .symbol => {
                if (rule.value) |sym| {
                    return nullable_map.get(sym) orelse false;
                }
                return false;
            },
            .choice => {
                for (rule.children) |c| {
                    if (self.checkNullable(c, nullable_map)) return true;
                }
                return false;
            },
            .seq => {
                for (rule.children) |c| {
                    if (!self.checkNullable(c, nullable_map)) return false;
                }
                return true;
            },
            .repeat1, .field, .alias, .prec, .prec_left, .prec_right, .token => {
                for (rule.children) |c| {
                    if (!self.checkNullable(c, nullable_map)) return false;
                }
                return true;
            },
            else => return false,
        }
    }

    fn collectFirst(self: *GrammarCompiler, rule: Rule, first_set: *std.StringHashMap(void), sets: *FirstFollowSets) !void {
        switch (rule.tag) {
            .string, .pattern => {
                if (rule.value) |val| {
                    try first_set.put(val, {});
                }
            },
            .symbol => {
                if (rule.value) |sym| {
                    if (sets.first.get(sym)) |sub_first| {
                        var it = sub_first.keyIterator();
                        while (it.next()) |k| {
                            try first_set.put(k.*, {});
                        }
                    }
                }
            },
            .choice => {
                for (rule.children) |c| {
                    try self.collectFirst(c, first_set, sets);
                }
            },
            .seq => {
                for (rule.children) |c| {
                    try self.collectFirst(c, first_set, sets);
                    if (!self.checkNullable(c, &sets.nullable)) break;
                }
            },
            .repeat, .repeat1, .optional, .field, .alias, .prec, .prec_left, .prec_right, .token => {
                for (rule.children) |c| {
                    try self.collectFirst(c, first_set, sets);
                }
            },
            else => {},
        }
    }
};

test "compiler: validate grammar and compute first/follow" {
    var g = try Grammar.init(std.testing.allocator, "calc");
    defer g.deinit(std.testing.allocator);

    try g.addRule(std.testing.allocator, "expression", Rule.seq(&.{
        Rule.sym("number"),
        Rule.str("+"),
        Rule.sym("number"),
    }));
    try g.addRule(std.testing.allocator, "number", Rule.pattern("\\d+"));

    var compiler = GrammarCompiler.init(std.testing.allocator, &g);
    defer compiler.deinit();

    try compiler.validate();

    var sets = try compiler.computeFirstFollow();
    defer sets.deinit();

    const expr_first = sets.first.get("expression").?;
    try std.testing.expect(expr_first.contains("\\d+"));
    try std.testing.expectEqual(false, sets.nullable.get("expression").?);
}
