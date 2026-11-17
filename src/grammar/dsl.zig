const std = @import("std");
const grammar_mod = @import("ast.zig");
const Rule = grammar_mod.Rule;
const Grammar = grammar_mod.Grammar;

pub const DSLParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) DSLParser {
        return .{ .allocator = allocator };
    }

    pub fn parseFile(self: *DSLParser, io: std.Io, file_path: []const u8) !Grammar {
        const content = try std.Io.Dir.cwd().readFileAlloc(io, file_path, self.allocator, .limited(16 * 1024 * 1024));
        defer self.allocator.free(content);

        return self.parseJSON(content);
    }

    pub fn parseJSON(self: *DSLParser, json_text: []const u8) !Grammar {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json_text, .{});
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return error.InvalidGrammarJSON;

        const name_val = root.object.get("name") orelse return error.MissingGrammarName;
        if (name_val != .string) return error.InvalidGrammarName;

        var g = try Grammar.init(self.allocator, name_val.string);
        errdefer g.deinit(self.allocator);

        // Rules
        if (root.object.get("rules")) |rules_val| {
            if (rules_val == .object) {
                var it = rules_val.object.iterator();
                while (it.next()) |entry| {
                    const rule = try self.parseRuleValue(entry.value_ptr.*);
                    try g.addRule(self.allocator, entry.key_ptr.*, rule);
                }
            }
        }

        // Extras
        if (root.object.get("extras")) |extras_val| {
            if (extras_val == .array) {
                for (extras_val.array.items) |item| {
                    const r = try self.parseRuleValue(item);
                    try g.addExtra(self.allocator, r);
                }
            }
        }

        // Externals
        if (root.object.get("externals")) |ext_val| {
            if (ext_val == .array) {
                for (ext_val.array.items) |item| {
                    const r = try self.parseRuleValue(item);
                    try g.addExternal(self.allocator, r);
                }
            }
        }

        // Inline
        if (root.object.get("inline")) |inl_val| {
            if (inl_val == .array) {
                for (inl_val.array.items) |item| {
                    if (item == .string) {
                        try g.inline_rules.append(self.allocator, try self.allocator.dupe(u8, item.string));
                    }
                }
            }
        }

        // Supertypes
        if (root.object.get("supertypes")) |sup_val| {
            if (sup_val == .array) {
                for (sup_val.array.items) |item| {
                    if (item == .string) {
                        try g.supertypes.append(self.allocator, try self.allocator.dupe(u8, item.string));
                    }
                }
            }
        }

        // Word
        if (root.object.get("word")) |w_val| {
            if (w_val == .string) {
                g.word = try self.allocator.dupe(u8, w_val.string);
            }
        }

        // Conflicts
        if (root.object.get("conflicts")) |conf_val| {
            if (conf_val == .array) {
                for (conf_val.array.items) |c_set| {
                    if (c_set == .array) {
                        var syms = try self.allocator.alloc([]const u8, c_set.array.items.len);
                        for (c_set.array.items, 0..) |s, i| {
                            if (s == .string) {
                                syms[i] = try self.allocator.dupe(u8, s.string);
                            } else {
                                syms[i] = "";
                            }
                        }
                        try g.conflicts.append(self.allocator, syms);
                    }
                }
            }
        }

        return g;
    }

    fn parseRuleValue(self: *DSLParser, val: std.json.Value) !Rule {
        if (val != .object) return error.InvalidRuleValue;

        const type_val = val.object.get("type") orelse return error.MissingRuleType;
        if (type_val != .string) return error.InvalidRuleType;
        const tag_name = type_val.string;

        if (std.mem.eql(u8, tag_name, "BLANK")) {
            return Rule.blank();
        } else if (std.mem.eql(u8, tag_name, "EOF")) {
            return Rule.eof();
        } else if (std.mem.eql(u8, tag_name, "STRING")) {
            const v = val.object.get("value") orelse return error.MissingStringValue;
            if (v != .string) return error.InvalidStringValue;
            const str_val = try self.allocator.dupe(u8, v.string);
            var r = Rule.str(str_val);
            r.is_owned = true;
            return r;
        } else if (std.mem.eql(u8, tag_name, "PATTERN")) {
            const v = val.object.get("value") orelse return error.MissingPatternValue;
            if (v != .string) return error.InvalidPatternValue;
            const pat_val = try self.allocator.dupe(u8, v.string);
            var r = Rule.pattern(pat_val);
            r.is_owned = true;
            return r;
        } else if (std.mem.eql(u8, tag_name, "SYMBOL")) {
            const n = val.object.get("name") orelse return error.MissingSymbolName;
            if (n != .string) return error.InvalidSymbolName;
            const sym_name = try self.allocator.dupe(u8, n.string);
            var r = Rule.sym(sym_name);
            r.is_owned = true;
            return r;
        } else if (std.mem.eql(u8, tag_name, "CHOICE")) {
            const m = val.object.get("members") orelse return error.MissingChoiceMembers;
            if (m != .array) return error.InvalidChoiceMembers;
            var list = try self.allocator.alloc(Rule, m.array.items.len);
            for (m.array.items, 0..) |item, i| {
                list[i] = try self.parseRuleValue(item);
            }
            var r = Rule.choice(list);
            r.is_owned = true;
            return r;
        } else if (std.mem.eql(u8, tag_name, "SEQ")) {
            const m = val.object.get("members") orelse return error.MissingSeqMembers;
            if (m != .array) return error.InvalidSeqMembers;
            var list = try self.allocator.alloc(Rule, m.array.items.len);
            for (m.array.items, 0..) |item, i| {
                list[i] = try self.parseRuleValue(item);
            }
            var r = Rule.seq(list);
            r.is_owned = true;
            return r;
        } else if (std.mem.eql(u8, tag_name, "REPEAT")) {
            const c = val.object.get("content") orelse return error.MissingRepeatContent;
            const child = try self.parseRuleValue(c);
            return try Rule.repeat(child, self.allocator);
        } else if (std.mem.eql(u8, tag_name, "REPEAT1")) {
            const c = val.object.get("content") orelse return error.MissingRepeatContent;
            const child = try self.parseRuleValue(c);
            return try Rule.repeat1(child, self.allocator);
        } else if (std.mem.eql(u8, tag_name, "FIELD")) {
            const fn_val = val.object.get("name") orelse return error.MissingFieldName;
            if (fn_val != .string) return error.InvalidFieldName;
            const fname = try self.allocator.dupe(u8, fn_val.string);
            const c = val.object.get("content") orelse return error.MissingFieldContent;
            const child = try self.parseRuleValue(c);
            var r = try Rule.field(fname, child, self.allocator);
            r.is_owned = true;
            return r;
        } else if (std.mem.eql(u8, tag_name, "ALIAS")) {
            const v = val.object.get("value") orelse return error.MissingAliasValue;
            if (v != .string) return error.InvalidAliasValue;
            const alias_val = try self.allocator.dupe(u8, v.string);
            var is_named = true;
            if (val.object.get("named")) |nv| {
                if (nv == .bool) is_named = nv.bool;
            }
            const c = val.object.get("content") orelse return error.MissingAliasContent;
            const child = try self.parseRuleValue(c);
            var r = try Rule.alias(alias_val, is_named, child, self.allocator);
            r.is_owned = true;
            return r;
        } else if (std.mem.eql(u8, tag_name, "PREC")) {
            var prec_val: i32 = 0;
            if (val.object.get("value")) |pv| {
                if (pv == .integer) {
                    prec_val = @as(i32, @intCast(pv.integer));
                }
            }
            const c = val.object.get("content") orelse return error.MissingPrecContent;
            const child = try self.parseRuleValue(c);
            return try Rule.prec(prec_val, child, self.allocator);
        } else if (std.mem.eql(u8, tag_name, "PREC_LEFT")) {
            var prec_val: i32 = 0;
            if (val.object.get("value")) |pv| {
                if (pv == .integer) {
                    prec_val = @as(i32, @intCast(pv.integer));
                }
            }
            const c = val.object.get("content") orelse return error.MissingPrecContent;
            const child = try self.parseRuleValue(c);
            return try Rule.precLeft(prec_val, child, self.allocator);
        } else if (std.mem.eql(u8, tag_name, "PREC_RIGHT")) {
            var prec_val: i32 = 0;
            if (val.object.get("value")) |pv| {
                if (pv == .integer) {
                    prec_val = @as(i32, @intCast(pv.integer));
                }
            }
            const c = val.object.get("content") orelse return error.MissingPrecContent;
            const child = try self.parseRuleValue(c);
            return try Rule.precRight(prec_val, child, self.allocator);
        } else if (std.mem.eql(u8, tag_name, "PREC_DYNAMIC")) {
            var prec_val: i32 = 0;
            if (val.object.get("value")) |pv| {
                if (pv == .integer) {
                    prec_val = @as(i32, @intCast(pv.integer));
                }
            }
            const c = val.object.get("content") orelse return error.MissingPrecContent;
            const child = try self.parseRuleValue(c);
            const slice = try self.allocator.alloc(Rule, 1);
            slice[0] = child;
            return .{ .tag = .prec_dynamic, .integer_val = prec_val, .children = slice, .is_owned = true };
        } else if (std.mem.eql(u8, tag_name, "TOKEN") or std.mem.eql(u8, tag_name, "IMMEDIATE_TOKEN")) {
            const c = val.object.get("content") orelse return error.MissingTokenContent;
            const child = try self.parseRuleValue(c);
            return try Rule.token(child, self.allocator);
        } else if (std.mem.eql(u8, tag_name, "RESERVED")) {
            const c = val.object.get("content") orelse return error.MissingTokenContent;
            return try self.parseRuleValue(c);
        }

        return error.UnsupportedRuleType;
    }
};

test "dsl: parse minimal grammar.json" {
    const sample_json =
        \\{
        \\  "name": "calc",
        \\  "rules": {
        \\    "expression": {
        \\      "type": "CHOICE",
        \\      "members": [
        \\        { "type": "SYMBOL", "name": "number" },
        \\        {
        \\          "type": "PREC_LEFT",
        \\          "value": 1,
        \\          "content": {
        \\            "type": "SEQ",
        \\            "members": [
        \\              { "type": "SYMBOL", "name": "expression" },
        \\              { "type": "STRING", "value": "+" },
        \\              { "type": "SYMBOL", "name": "expression" }
        \\            ]
        \\          }
        \\        }
        \\      ]
        \\    },
        \\    "number": {
        \\      "type": "PATTERN",
        \\      "value": "\\d+"
        \\    }
        \\  },
        \\  "extras": [
        \\    { "type": "PATTERN", "value": "\\s" }
        \\  ]
        \\}
    ;

    var parser = DSLParser.init(std.testing.allocator);
    var g = try parser.parseJSON(sample_json);
    defer g.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("calc", g.name);
    try std.testing.expectEqual(@as(usize, 2), g.rules.items.len);
    try std.testing.expectEqual(@as(usize, 1), g.extras.items.len);
}

test "dsl: parse real tree-sitter-json grammar.json via parseFile" {
    const json_path = "grammars/tree-sitter-json/src/grammar.json";

    var parser = DSLParser.init(std.testing.allocator);
    var g = parser.parseFile(std.testing.io, json_path) catch return;
    defer g.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("json", g.name);
    try std.testing.expect(g.rules.items.len > 0);
}
