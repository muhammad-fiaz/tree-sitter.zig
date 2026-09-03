const std = @import("std");
const language_mod = @import("language.zig");
const symbols_mod = @import("symbols.zig");
const tables_mod = @import("tables.zig");
const fields_mod = @import("fields.zig");
const metadata_mod = @import("metadata.zig");

/// Bundled JSON grammar tables (see `json_language` below).
///
/// Symbols and productions:
/// ```text
/// program  := value
/// value    := object | array | string | number | true | false | null
/// object   := "{" "}" | "{" members "}"
/// members  := pair | members "," pair
/// pair     := string ":" value           (fields: key, value)
/// array    := "[" "]" | "[" elements "]"
/// elements := value | elements "," value
/// ```
/// Whitespace is an extra. Strings enforce JSON quoting rules
/// (escapes, no raw control characters); numbers follow the JSON
/// number syntax (no leading zeros).
pub const sym_end: u16 = 0;
pub const sym_lbrace: u16 = 1;
pub const sym_rbrace: u16 = 2;
pub const sym_lbracket: u16 = 3;
pub const sym_rbracket: u16 = 4;
pub const sym_colon: u16 = 5;
pub const sym_comma: u16 = 6;
pub const sym_string: u16 = 7;
pub const sym_number: u16 = 8;
pub const sym_true: u16 = 9;
pub const sym_false: u16 = 10;
pub const sym_null: u16 = 11;
pub const sym_whitespace: u16 = 12;
pub const sym_program: u16 = 13;
pub const sym_value: u16 = 14;
pub const sym_object: u16 = 15;
pub const sym_members: u16 = 16;
pub const sym_pair: u16 = 17;
pub const sym_array: u16 = 18;
pub const sym_elements: u16 = 19;
pub const sym_error: u16 = 20;

fn matchJsonString(source: []const u8, start: usize) ?usize {
    if (start >= source.len or source[start] != '"') return null;
    var i = start + 1;
    while (i < source.len) {
        const c = source[i];
        if (c == '"') return i + 1 - start;
        if (c == '\\') {
            i += 1;
            if (i >= source.len) return null;
            switch (source[i]) {
                '"', '\\', '/', 'b', 'f', 'n', 'r', 't' => i += 1,
                'u' => {
                    if (i + 4 >= source.len) return null;
                    for (source[i + 1 .. i + 5]) |h| {
                        if (!std.ascii.isHex(h)) return null;
                    }
                    i += 5;
                },
                else => return null,
            }
        } else {
            if (c < 0x20) return null;
            i += 1;
        }
    }
    return null;
}

fn matchJsonNumber(source: []const u8, start: usize) ?usize {
    var i = start;
    if (i < source.len and source[i] == '-') i += 1;
    if (i >= source.len) return null;
    if (source[i] == '0') {
        i += 1;
    } else if (std.ascii.isDigit(source[i])) {
        while (i < source.len and std.ascii.isDigit(source[i])) : (i += 1) {}
    } else {
        return null;
    }
    if (i < source.len and source[i] == '.') {
        i += 1;
        if (i >= source.len or !std.ascii.isDigit(source[i])) return null;
        while (i < source.len and std.ascii.isDigit(source[i])) : (i += 1) {}
    }
    if (i < source.len and (source[i] == 'e' or source[i] == 'E')) {
        i += 1;
        if (i < source.len and (source[i] == '+' or source[i] == '-')) i += 1;
        if (i >= source.len or !std.ascii.isDigit(source[i])) return null;
        while (i < source.len and std.ascii.isDigit(source[i])) : (i += 1) {}
    }
    return i - start;
}

fn matchKeyword(comptime word: []const u8) language_mod.TokenMatchFn {
    return struct {
        fn match(source: []const u8, start: usize) ?usize {
            if (start + word.len > source.len) return null;
            if (!std.mem.eql(u8, source[start .. start + word.len], word)) return null;
            return word.len;
        }
    }.match;
}

const symbol_table: []const symbols_mod.SymbolInfo = &.{
    .{ .id = sym_end, .name = "end", .kind = .end, .metadata = .{ .visible = false, .named = false } },
    .{ .id = sym_lbrace, .name = "{", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rbrace, .name = "}", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lbracket, .name = "[", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rbracket, .name = "]", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_colon, .name = ":", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_comma, .name = ",", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_string, .name = "string", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_number, .name = "number", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_true, .name = "true", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_false, .name = "false", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_null, .name = "null", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = false, .named = false, .extra = true } },
    .{ .id = sym_program, .name = "program", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_value, .name = "value", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_object, .name = "object", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_members, .name = "members", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_pair, .name = "pair", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_array, .name = "array", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_elements, .name = "elements", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_error, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const token_matchers: []const language_mod.TokenMatcher = &.{
    .{ .symbol = sym_string, .match = matchJsonString },
    .{ .symbol = sym_number, .match = matchJsonNumber },
    .{ .symbol = sym_true, .match = matchKeyword("true") },
    .{ .symbol = sym_false, .match = matchKeyword("false") },
    .{ .symbol = sym_null, .match = matchKeyword("null") },
    .{ .symbol = sym_lbrace, .match = language_mod.matchChar('{') },
    .{ .symbol = sym_rbrace, .match = language_mod.matchChar('}') },
    .{ .symbol = sym_lbracket, .match = language_mod.matchChar('[') },
    .{ .symbol = sym_rbracket, .match = language_mod.matchChar(']') },
    .{ .symbol = sym_colon, .match = language_mod.matchChar(':') },
    .{ .symbol = sym_comma, .match = language_mod.matchChar(',') },
    .{ .symbol = sym_whitespace, .match = language_mod.matchWhitespace },
};

const extra_symbols: []const u16 = &.{sym_whitespace};

const s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 5 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 6 } },
    .{ .symbol = sym_string, .action = .{ .shift = 21 } },
    .{ .symbol = sym_number, .action = .{ .shift = 22 } },
    .{ .symbol = sym_true, .action = .{ .shift = 23 } },
    .{ .symbol = sym_false, .action = .{ .shift = 24 } },
    .{ .symbol = sym_null, .action = .{ .shift = 25 } },
};
const s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_program, .state = 1 },
    .{ .symbol = sym_value, .state = 2 },
    .{ .symbol = sym_object, .state = 3 },
    .{ .symbol = sym_array, .state = 4 },
};
const s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .accept },
};
const s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_program, .child_count = 1, .production_id = 1 } } },
};
// Value-unit reductions, valid on any value follower.
const s_value_object: tables_mod.Action = .{ .reduce = .{ .symbol = sym_value, .child_count = 1, .production_id = 2 } };
const s_value_array: tables_mod.Action = .{ .reduce = .{ .symbol = sym_value, .child_count = 1, .production_id = 3 } };
const s_value_string: tables_mod.Action = .{ .reduce = .{ .symbol = sym_value, .child_count = 1, .production_id = 4 } };
const s_value_number: tables_mod.Action = .{ .reduce = .{ .symbol = sym_value, .child_count = 1, .production_id = 5 } };
const s_value_true: tables_mod.Action = .{ .reduce = .{ .symbol = sym_value, .child_count = 1, .production_id = 6 } };
const s_value_false: tables_mod.Action = .{ .reduce = .{ .symbol = sym_value, .child_count = 1, .production_id = 7 } };
const s_value_null: tables_mod.Action = .{ .reduce = .{ .symbol = sym_value, .child_count = 1, .production_id = 8 } };

const s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = s_value_object },
    .{ .symbol = sym_comma, .action = s_value_object },
    .{ .symbol = sym_rbrace, .action = s_value_object },
    .{ .symbol = sym_rbracket, .action = s_value_object },
};
const s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = s_value_array },
    .{ .symbol = sym_comma, .action = s_value_array },
    .{ .symbol = sym_rbrace, .action = s_value_array },
    .{ .symbol = sym_rbracket, .action = s_value_array },
};
const s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_rbrace, .action = .{ .shift = 15 } },
    .{ .symbol = sym_string, .action = .{ .shift = 7 } },
};
const s5_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_members, .state = 11 },
    .{ .symbol = sym_pair, .state = 10 },
};
const s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 5 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 6 } },
    .{ .symbol = sym_string, .action = .{ .shift = 21 } },
    .{ .symbol = sym_number, .action = .{ .shift = 22 } },
    .{ .symbol = sym_true, .action = .{ .shift = 23 } },
    .{ .symbol = sym_false, .action = .{ .shift = 24 } },
    .{ .symbol = sym_null, .action = .{ .shift = 25 } },
    .{ .symbol = sym_rbracket, .action = .{ .shift = 20 } },
};
const s6_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_elements, .state = 16 },
    .{ .symbol = sym_value, .state = 17 },
    .{ .symbol = sym_object, .state = 3 },
    .{ .symbol = sym_array, .state = 4 },
};
const s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon, .action = .{ .shift = 8 } },
};
const s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 5 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 6 } },
    .{ .symbol = sym_string, .action = .{ .shift = 21 } },
    .{ .symbol = sym_number, .action = .{ .shift = 22 } },
    .{ .symbol = sym_true, .action = .{ .shift = 23 } },
    .{ .symbol = sym_false, .action = .{ .shift = 24 } },
    .{ .symbol = sym_null, .action = .{ .shift = 25 } },
};
const s8_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_value, .state = 9 },
    .{ .symbol = sym_object, .state = 3 },
    .{ .symbol = sym_array, .state = 4 },
};
const s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_pair, .child_count = 3, .production_id = 13 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_pair, .child_count = 3, .production_id = 13 } } },
};
const s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_members, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_members, .child_count = 1, .production_id = 11 } } },
};
const s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 12 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 14 } },
};
const s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_string, .action = .{ .shift = 7 } },
};
const s12_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_pair, .state = 13 },
};
const s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_members, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_members, .child_count = 3, .production_id = 12 } } },
};
const s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 3, .production_id = 10 } } },
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 3, .production_id = 10 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 3, .production_id = 10 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 3, .production_id = 10 } } },
};
const s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 2, .production_id = 9 } } },
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 2, .production_id = 9 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 2, .production_id = 9 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 2, .production_id = 9 } } },
};
const s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 18 } },
    .{ .symbol = sym_rbracket, .action = .{ .shift = 19 } },
};
const s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 1, .production_id = 16 } } },
};
const s18_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 5 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 6 } },
    .{ .symbol = sym_string, .action = .{ .shift = 21 } },
    .{ .symbol = sym_number, .action = .{ .shift = 22 } },
    .{ .symbol = sym_true, .action = .{ .shift = 23 } },
    .{ .symbol = sym_false, .action = .{ .shift = 24 } },
    .{ .symbol = sym_null, .action = .{ .shift = 25 } },
};
const s18_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_value, .state = 26 },
    .{ .symbol = sym_object, .state = 3 },
    .{ .symbol = sym_array, .state = 4 },
};
const s19_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 3, .production_id = 15 } } },
};
const s20_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 2, .production_id = 14 } } },
};
const s26_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 3, .production_id = 17 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 3, .production_id = 17 } } },
};

const s21_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = s_value_string },
    .{ .symbol = sym_comma, .action = s_value_string },
    .{ .symbol = sym_rbrace, .action = s_value_string },
    .{ .symbol = sym_rbracket, .action = s_value_string },
};
const s22_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = s_value_number },
    .{ .symbol = sym_comma, .action = s_value_number },
    .{ .symbol = sym_rbrace, .action = s_value_number },
    .{ .symbol = sym_rbracket, .action = s_value_number },
};
const s23_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = s_value_true },
    .{ .symbol = sym_comma, .action = s_value_true },
    .{ .symbol = sym_rbrace, .action = s_value_true },
    .{ .symbol = sym_rbracket, .action = s_value_true },
};
const s24_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = s_value_false },
    .{ .symbol = sym_comma, .action = s_value_false },
    .{ .symbol = sym_rbrace, .action = s_value_false },
    .{ .symbol = sym_rbracket, .action = s_value_false },
};
const s25_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = s_value_null },
    .{ .symbol = sym_comma, .action = s_value_null },
    .{ .symbol = sym_rbrace, .action = s_value_null },
    .{ .symbol = sym_rbracket, .action = s_value_null },
};

const parse_states: []const tables_mod.ParseState = &.{
    .{ .actions = s0_actions, .gotos = s0_gotos }, // 0
    .{ .actions = s1_actions }, // 1
    .{ .actions = s2_actions }, // 2
    .{ .actions = s3_actions }, // 3
    .{ .actions = s4_actions }, // 4
    .{ .actions = s5_actions, .gotos = s5_gotos }, // 5
    .{ .actions = s6_actions, .gotos = s6_gotos }, // 6
    .{ .actions = s7_actions }, // 7
    .{ .actions = s8_actions, .gotos = s8_gotos }, // 8
    .{ .actions = s9_actions }, // 9
    .{ .actions = s10_actions }, // 10
    .{ .actions = s11_actions }, // 11
    .{ .actions = s12_actions, .gotos = s12_gotos }, // 12
    .{ .actions = s13_actions }, // 13
    .{ .actions = s14_actions }, // 14
    .{ .actions = s15_actions }, // 15
    .{ .actions = s16_actions }, // 16
    .{ .actions = s17_actions }, // 17
    .{ .actions = s18_actions, .gotos = s18_gotos }, // 18
    .{ .actions = s19_actions }, // 19
    .{ .actions = s20_actions }, // 20
    .{ .actions = s21_actions }, // 21 string
    .{ .actions = s22_actions }, // 22 number
    .{ .actions = s23_actions }, // 23 true
    .{ .actions = s24_actions }, // 24 false
    .{ .actions = s25_actions }, // 25 null
    .{ .actions = s26_actions }, // 26
};

const field_names: []const []const u8 = &.{ "key", "value" };
const field_productions: []const fields_mod.FieldProduction = &.{
    .{ .production_id = 13, .bindings = &.{ .{ .name = "key", .child_index = 0 }, .{ .name = "value", .child_index = 2 } } },
};

/// Bundled JSON grammar: objects, arrays, strings (strict quoting),
/// numbers, and literals, with `key`/`value` fields on pairs.
pub const json_language: language_mod.Language = .{
    .metadata = .{
        .name = "json",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.1",
        .symbol_count = 21,
        .state_count = 27,
        .field_count = 2,
    },
    .symbols = symbol_table,
    .token_matchers = token_matchers,
    .extra_symbols = extra_symbols,
    .table = .{
        .states = parse_states,
        .start_state = 0,
        .end_symbol = sym_end,
        .error_symbol = sym_error,
    },
    .fields = .{
        .names = field_names,
        .productions = field_productions,
    },
};

test "json: string matcher enforces quoting rules" {
    try std.testing.expectEqual(@as(?usize, 5), matchJsonString("\"abc\"", 0));
    try std.testing.expectEqual(@as(?usize, 6), matchJsonString("\"a\\nb\"", 0));
    try std.testing.expectEqual(@as(?usize, 9), matchJsonString("\"a\\u0041\"", 0));
    try std.testing.expect(matchJsonString("\"abc", 0) == null);
    try std.testing.expect(matchJsonString("\"a\\qb\"", 0) == null);
    try std.testing.expect(matchJsonString("\"a\nb\"", 0) == null);
    try std.testing.expect(matchJsonString("abc", 0) == null);
}

test "json: number matcher follows number syntax" {
    try std.testing.expectEqual(@as(?usize, 3), matchJsonNumber("123", 0));
    try std.testing.expectEqual(@as(?usize, 4), matchJsonNumber("-0.5", 0));
    try std.testing.expectEqual(@as(?usize, 5), matchJsonNumber("1.2e3", 0));
    try std.testing.expectEqual(@as(?usize, 1), matchJsonNumber("0", 0));
    try std.testing.expect(matchJsonNumber("", 0) == null);
    try std.testing.expect(matchJsonNumber("-", 0) == null);
    try std.testing.expect(matchJsonNumber("1.", 0) == null);
    try std.testing.expect(matchJsonNumber("1e", 0) == null);
}
