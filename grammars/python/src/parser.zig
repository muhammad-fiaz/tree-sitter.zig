const std = @import("std");
const treesitter = @import("treesitter");
const language_mod = treesitter.language_mod;
const symbols_mod = language_mod.symbols;
const tables_mod = language_mod.tables;
const fields_mod = language_mod.fields;
const metadata_mod = language_mod.metadata;
const Language = treesitter.Language;
const TokenMatcher = treesitter.TokenMatcher;

pub const sym_end: u16 = 0;
pub const sym_newline: u16 = 1;
pub const sym_indent: u16 = 2;
pub const sym_dedent: u16 = 3;
pub const sym_def: u16 = 4;
pub const sym_class: u16 = 5;
pub const sym_return: u16 = 6;
pub const sym_pass: u16 = 7;
pub const sym_True: u16 = 8;
pub const sym_False: u16 = 9;
pub const sym_None: u16 = 10;
pub const sym_colon: u16 = 11;
pub const sym_comma: u16 = 12;
pub const sym_lparen: u16 = 13;
pub const sym_rparen: u16 = 14;
pub const sym_eq: u16 = 15;
pub const sym_plus: u16 = 16;
pub const sym_minus: u16 = 17;
pub const sym_star: u16 = 18;
pub const sym_identifier: u16 = 19;
pub const sym_integer: u16 = 20;
pub const sym_string: u16 = 21;
pub const sym_whitespace_horizontal: u16 = 22;
pub const sym_comment: u16 = 23;
pub const sym_module: u16 = 24;
pub const sym_statements: u16 = 25;
pub const sym_statement: u16 = 26;
pub const sym_function_definition: u16 = 27;
pub const sym_parameter_list: u16 = 28;
pub const sym_class_definition: u16 = 29;
pub const sym_block: u16 = 30;
pub const sym_simple_statements: u16 = 31;
pub const sym_return_statement: u16 = 32;
pub const sym_expression_statement: u16 = 33;
pub const sym_pass_statement: u16 = 34;
pub const sym_expression: u16 = 35;
pub const sym_assignment: u16 = 36;
pub const sym_binary_operator: u16 = 37;
pub const sym_call: u16 = 38;
pub const sym_argument_list: u16 = 39;
pub const sym_primary: u16 = 40;
pub const sym_ERROR: u16 = 41;

fn matchKeyword(comptime word: []const u8) language_mod.TokenMatchFn {
    return struct {
        fn match(source: []const u8, start: usize) ?usize {
            if (start + word.len > source.len) return null;
            if (!std.mem.eql(u8, source[start .. start + word.len], word)) return null;
            if (start + word.len < source.len) {
                const next_c = source[start + word.len];
                if (std.ascii.isAlphanumeric(next_c) or next_c == '_') return null;
            }
            return word.len;
        }
    }.match;
}

fn matchLiteral(comptime lit: []const u8) language_mod.TokenMatchFn {
    return struct {
        fn match(source: []const u8, start: usize) ?usize {
            if (start + lit.len > source.len) return null;
            if (!std.mem.eql(u8, source[start .. start + lit.len], lit)) return null;
            return lit.len;
        }
    }.match;
}

fn matchIdentifier(source: []const u8, start: usize) ?usize {
    if (start >= source.len) return null;
    const first = source[start];
    if (!std.ascii.isAlphabetic(first) and first != '_') return null;
    var i = start + 1;
    while (i < source.len and (std.ascii.isAlphanumeric(source[i]) or source[i] == '_')) : (i += 1) {}
    return i - start;
}

fn matchNumber(source: []const u8, start: usize) ?usize {
    if (start >= source.len or !std.ascii.isDigit(source[start])) return null;
    var i = start + 1;
    while (i < source.len and (std.ascii.isDigit(source[i]) or source[i] == '.')) : (i += 1) {}
    return i - start;
}

fn matchString(source: []const u8, start: usize) ?usize {
    if (start >= source.len) return null;
    const quote = source[start];
    if (quote != '"' and quote != '\'') return null;
    var i = start + 1;
    while (i < source.len) {
        if (source[i] == '\\') {
            i += 2;
        } else if (source[i] == quote) {
            return i + 1 - start;
        } else {
            i += 1;
        }
    }
    return null;
}

fn matchComment(source: []const u8, start: usize) ?usize {
    if (start + 1 < source.len and source[start] == '/' and source[start + 1] == '/') {
        var i = start + 2;
        while (i < source.len and source[i] != '\n') : (i += 1) {}
        return i - start;
    }
    if (start + 1 < source.len and source[start] == '/' and source[start + 1] == '*') {
        var i = start + 2;
        while (i + 1 < source.len) : (i += 1) {
            if (source[i] == '*' and source[i + 1] == '/') return i + 2 - start;
        }
        return source.len - start;
    }

    if (start < source.len and source[start] == '#') {
        var i = start + 1;
        while (i < source.len and source[i] != '\n') : (i += 1) {}
        return i - start;
    }
    return null;
}

const symbol_table: []const symbols_mod.SymbolInfo = &.{
    .{ .id = sym_end, .name = "end", .kind = .end, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_newline, .name = "_newline", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_indent, .name = "_indent", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_dedent, .name = "_dedent", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_def, .name = "def", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_class, .name = "class", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_return, .name = "return", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_pass, .name = "pass", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_True, .name = "True", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_False, .name = "False", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_None, .name = "None", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_colon, .name = ":", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_comma, .name = ",", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lparen, .name = "(", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rparen, .name = ")", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_eq, .name = "=", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_plus, .name = "+", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_minus, .name = "-", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_star, .name = "*", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_identifier, .name = "identifier", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_integer, .name = "integer", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_string, .name = "string", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_whitespace_horizontal, .name = "whitespace_horizontal", .kind = .terminal, .metadata = .{ .visible = true, .named = false, .extra = true } },
    .{ .id = sym_comment, .name = "comment", .kind = .terminal, .metadata = .{ .visible = true, .named = true, .extra = true } },
    .{ .id = sym_module, .name = "module", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statements, .name = "statements", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statement, .name = "statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_function_definition, .name = "function_definition", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_parameter_list, .name = "parameter_list", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_class_definition, .name = "class_definition", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_block, .name = "block", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_simple_statements, .name = "simple_statements", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_return_statement, .name = "return_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expression_statement, .name = "expression_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_pass_statement, .name = "pass_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expression, .name = "expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_assignment, .name = "assignment", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_binary_operator, .name = "binary_operator", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_call, .name = "call", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_argument_list, .name = "argument_list", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_primary, .name = "primary", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_ERROR, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const token_matchers: []const language_mod.TokenMatcher = &.{
    .{ .symbol = sym_def, .match = matchKeyword("def") },
    .{ .symbol = sym_class, .match = matchKeyword("class") },
    .{ .symbol = sym_return, .match = matchKeyword("return") },
    .{ .symbol = sym_pass, .match = matchKeyword("pass") },
    .{ .symbol = sym_True, .match = matchKeyword("True") },
    .{ .symbol = sym_False, .match = matchKeyword("False") },
    .{ .symbol = sym_None, .match = matchKeyword("None") },
    .{ .symbol = sym_colon, .match = language_mod.matchChar(':') },
    .{ .symbol = sym_comma, .match = language_mod.matchChar(',') },
    .{ .symbol = sym_lparen, .match = language_mod.matchChar('(') },
    .{ .symbol = sym_rparen, .match = language_mod.matchChar(')') },
    .{ .symbol = sym_eq, .match = language_mod.matchChar('=') },
    .{ .symbol = sym_plus, .match = language_mod.matchChar('+') },
    .{ .symbol = sym_minus, .match = language_mod.matchChar('-') },
    .{ .symbol = sym_star, .match = language_mod.matchChar('*') },
    .{ .symbol = sym_identifier, .match = matchIdentifier },
    .{ .symbol = sym_integer, .match = matchNumber },
    .{ .symbol = sym_string, .match = matchString },
    .{ .symbol = sym_whitespace_horizontal, .match = struct {
        fn match(source: []const u8, start: usize) ?usize {
            if (start >= source.len) return null;
            var i = start;
            while (i < source.len and (source[i] == ' ' or source[i] == '\t')) : (i += 1) {}
            return if (i > start) i - start else null;
        }
    }.match },
    .{ .symbol = sym_comment, .match = matchComment },
};

const extra_symbols: []const u16 = &.{ sym_whitespace_horizontal, sym_comment };

const s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_pass, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_assignment, .state = 20 },
    .{ .symbol = sym_binary_operator, .state = 21 },
    .{ .symbol = sym_call, .state = 22 },
    .{ .symbol = sym_class_definition, .state = 15 },
    .{ .symbol = sym_expression, .state = 19 },
    .{ .symbol = sym_expression_statement, .state = 17 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_module, .state = 11 },
    .{ .symbol = sym_pass_statement, .state = 18 },
    .{ .symbol = sym_primary, .state = 23 },
    .{ .symbol = sym_return_statement, .state = 16 },
    .{ .symbol = sym_statement, .state = 13 },
    .{ .symbol = sym_statements, .state = 12 },
};
const s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 24 } },
};
const s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 25 } },
};
const s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_newline, .action = .{ .shift = 26 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s3_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_assignment, .state = 20 },
    .{ .symbol = sym_binary_operator, .state = 21 },
    .{ .symbol = sym_call, .state = 22 },
    .{ .symbol = sym_expression, .state = 27 },
    .{ .symbol = sym_primary, .state = 23 },
};
const s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_newline, .action = .{ .shift = 28 } },
};
const s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 37 } } },
};
const s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 38 } } },
};
const s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 39 } } },
};
const s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_eq, .action = .{ .shift = 30 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 29 } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 34 } } },
};
const s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 35 } } },
};
const s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 36 } } },
};
const s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .accept },
};
const s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_module, .child_count = 1, .production_id = 1 } } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_pass, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s12_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_assignment, .state = 20 },
    .{ .symbol = sym_binary_operator, .state = 21 },
    .{ .symbol = sym_call, .state = 22 },
    .{ .symbol = sym_class_definition, .state = 15 },
    .{ .symbol = sym_expression, .state = 19 },
    .{ .symbol = sym_expression_statement, .state = 17 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_pass_statement, .state = 18 },
    .{ .symbol = sym_primary, .state = 23 },
    .{ .symbol = sym_return_statement, .state = 16 },
    .{ .symbol = sym_statement, .state = 31 },
};
const s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
};
const s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
};
const s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
};
const s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
};
const s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
};
const s18_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 8 } } },
};
const s19_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 34 } },
    .{ .symbol = sym_newline, .action = .{ .shift = 32 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 33 } },
    .{ .symbol = sym_star, .action = .{ .shift = 35 } },
};
const s20_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
};
const s21_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
};
const s22_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
};
const s23_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
};
const s24_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lparen, .action = .{ .shift = 36 } },
};
const s25_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon, .action = .{ .shift = 37 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 38 } },
};
const s26_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 19 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 19 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 19 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 19 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 19 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 19 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 19 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 19 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 19 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 19 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 19 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 19 } } },
};
const s27_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 34 } },
    .{ .symbol = sym_newline, .action = .{ .shift = 39 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 33 } },
    .{ .symbol = sym_star, .action = .{ .shift = 35 } },
};
const s28_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_pass_statement, .child_count = 2, .production_id = 21 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_pass_statement, .child_count = 2, .production_id = 21 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_pass_statement, .child_count = 2, .production_id = 21 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_pass_statement, .child_count = 2, .production_id = 21 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_pass_statement, .child_count = 2, .production_id = 21 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_pass_statement, .child_count = 2, .production_id = 21 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_pass_statement, .child_count = 2, .production_id = 21 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_pass_statement, .child_count = 2, .production_id = 21 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_pass_statement, .child_count = 2, .production_id = 21 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_pass_statement, .child_count = 2, .production_id = 21 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_pass_statement, .child_count = 2, .production_id = 21 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_pass_statement, .child_count = 2, .production_id = 21 } } },
};
const s29_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 40 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s29_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_argument_list, .state = 42 },
    .{ .symbol = sym_assignment, .state = 20 },
    .{ .symbol = sym_binary_operator, .state = 21 },
    .{ .symbol = sym_call, .state = 22 },
    .{ .symbol = sym_expression, .state = 41 },
    .{ .symbol = sym_primary, .state = 23 },
};
const s30_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s30_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_assignment, .state = 20 },
    .{ .symbol = sym_binary_operator, .state = 21 },
    .{ .symbol = sym_call, .state = 22 },
    .{ .symbol = sym_expression, .state = 43 },
    .{ .symbol = sym_primary, .state = 23 },
};
const s31_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
};
const s32_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 20 } } },
};
const s33_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 44 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s33_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary, .state = 45 },
};
const s34_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 44 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s34_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary, .state = 46 },
};
const s35_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 44 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s35_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary, .state = 47 },
};
const s36_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 49 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 48 } },
};
const s36_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_parameter_list, .state = 50 },
};
const s37_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_indent, .action = .{ .shift = 51 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_pass, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s37_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_assignment, .state = 20 },
    .{ .symbol = sym_binary_operator, .state = 21 },
    .{ .symbol = sym_block, .state = 53 },
    .{ .symbol = sym_call, .state = 22 },
    .{ .symbol = sym_class_definition, .state = 15 },
    .{ .symbol = sym_expression, .state = 19 },
    .{ .symbol = sym_expression_statement, .state = 17 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_pass_statement, .state = 18 },
    .{ .symbol = sym_primary, .state = 23 },
    .{ .symbol = sym_return_statement, .state = 16 },
    .{ .symbol = sym_simple_statements, .state = 54 },
    .{ .symbol = sym_statement, .state = 52 },
};
const s38_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 55 } },
};
const s39_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 18 } } },
};
const s40_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_call, .child_count = 3, .production_id = 31 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_call, .child_count = 3, .production_id = 31 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_call, .child_count = 3, .production_id = 31 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_call, .child_count = 3, .production_id = 31 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_call, .child_count = 3, .production_id = 31 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_call, .child_count = 3, .production_id = 31 } } },
};
const s41_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 34 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 33 } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_star, .action = .{ .shift = 35 } },
};
const s42_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 56 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 57 } },
};
const s43_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_assignment, .child_count = 3, .production_id = 26 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 34 } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_assignment, .child_count = 3, .production_id = 26 } } },
    .{ .symbol = sym_plus, .action = .{ .shift = 33 } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_assignment, .child_count = 3, .production_id = 26 } } },
    .{ .symbol = sym_star, .action = .{ .shift = 35 } },
};
const s44_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 34 } } },
};
const s45_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 27 } } },
};
const s46_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 28 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 28 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 28 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 28 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 28 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 28 } } },
};
const s47_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_binary_operator, .child_count = 3, .production_id = 29 } } },
};
const s48_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon, .action = .{ .shift = 58 } },
};
const s49_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 1, .production_id = 11 } } },
};
const s50_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 59 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 60 } },
};
const s51_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_pass, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s51_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_assignment, .state = 20 },
    .{ .symbol = sym_binary_operator, .state = 21 },
    .{ .symbol = sym_call, .state = 22 },
    .{ .symbol = sym_class_definition, .state = 15 },
    .{ .symbol = sym_expression, .state = 19 },
    .{ .symbol = sym_expression_statement, .state = 17 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_pass_statement, .state = 18 },
    .{ .symbol = sym_primary, .state = 23 },
    .{ .symbol = sym_return_statement, .state = 16 },
    .{ .symbol = sym_statement, .state = 13 },
    .{ .symbol = sym_statements, .state = 61 },
};
const s52_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_simple_statements, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_simple_statements, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_simple_statements, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_simple_statements, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_simple_statements, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_simple_statements, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_simple_statements, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_simple_statements, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_simple_statements, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_simple_statements, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_simple_statements, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_simple_statements, .child_count = 1, .production_id = 17 } } },
};
const s53_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
};
const s54_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 1, .production_id = 16 } } },
};
const s55_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_rparen, .action = .{ .shift = 62 } },
};
const s56_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s56_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_assignment, .state = 20 },
    .{ .symbol = sym_binary_operator, .state = 21 },
    .{ .symbol = sym_call, .state = 22 },
    .{ .symbol = sym_expression, .state = 63 },
    .{ .symbol = sym_primary, .state = 23 },
};
const s57_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_call, .child_count = 4, .production_id = 30 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_call, .child_count = 4, .production_id = 30 } } },
    .{ .symbol = sym_newline, .action = .{ .reduce = .{ .symbol = sym_call, .child_count = 4, .production_id = 30 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_call, .child_count = 4, .production_id = 30 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_call, .child_count = 4, .production_id = 30 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_call, .child_count = 4, .production_id = 30 } } },
};
const s58_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_indent, .action = .{ .shift = 51 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_pass, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s58_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_assignment, .state = 20 },
    .{ .symbol = sym_binary_operator, .state = 21 },
    .{ .symbol = sym_block, .state = 64 },
    .{ .symbol = sym_call, .state = 22 },
    .{ .symbol = sym_class_definition, .state = 15 },
    .{ .symbol = sym_expression, .state = 19 },
    .{ .symbol = sym_expression_statement, .state = 17 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_pass_statement, .state = 18 },
    .{ .symbol = sym_primary, .state = 23 },
    .{ .symbol = sym_return_statement, .state = 16 },
    .{ .symbol = sym_simple_statements, .state = 54 },
    .{ .symbol = sym_statement, .state = 52 },
};
const s59_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 65 } },
};
const s60_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon, .action = .{ .shift = 66 } },
};
const s61_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_dedent, .action = .{ .shift = 67 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_pass, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s61_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_assignment, .state = 20 },
    .{ .symbol = sym_binary_operator, .state = 21 },
    .{ .symbol = sym_call, .state = 22 },
    .{ .symbol = sym_class_definition, .state = 15 },
    .{ .symbol = sym_expression, .state = 19 },
    .{ .symbol = sym_expression_statement, .state = 17 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_pass_statement, .state = 18 },
    .{ .symbol = sym_primary, .state = 23 },
    .{ .symbol = sym_return_statement, .state = 16 },
    .{ .symbol = sym_statement, .state = 31 },
};
const s62_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon, .action = .{ .shift = 68 } },
};
const s63_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 3, .production_id = 33 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 34 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 33 } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 3, .production_id = 33 } } },
    .{ .symbol = sym_star, .action = .{ .shift = 35 } },
};
const s64_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 6, .production_id = 10 } } },
};
const s65_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 3, .production_id = 12 } } },
};
const s66_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_indent, .action = .{ .shift = 51 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_pass, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s66_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_assignment, .state = 20 },
    .{ .symbol = sym_binary_operator, .state = 21 },
    .{ .symbol = sym_block, .state = 69 },
    .{ .symbol = sym_call, .state = 22 },
    .{ .symbol = sym_class_definition, .state = 15 },
    .{ .symbol = sym_expression, .state = 19 },
    .{ .symbol = sym_expression_statement, .state = 17 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_pass_statement, .state = 18 },
    .{ .symbol = sym_primary, .state = 23 },
    .{ .symbol = sym_return_statement, .state = 16 },
    .{ .symbol = sym_simple_statements, .state = 54 },
    .{ .symbol = sym_statement, .state = 52 },
};
const s67_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 15 } } },
};
const s68_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .shift = 6 } },
    .{ .symbol = sym_None, .action = .{ .shift = 7 } },
    .{ .symbol = sym_True, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_indent, .action = .{ .shift = 51 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 9 } },
    .{ .symbol = sym_pass, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 10 } },
};
const s68_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_assignment, .state = 20 },
    .{ .symbol = sym_binary_operator, .state = 21 },
    .{ .symbol = sym_block, .state = 70 },
    .{ .symbol = sym_call, .state = 22 },
    .{ .symbol = sym_class_definition, .state = 15 },
    .{ .symbol = sym_expression, .state = 19 },
    .{ .symbol = sym_expression_statement, .state = 17 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_pass_statement, .state = 18 },
    .{ .symbol = sym_primary, .state = 23 },
    .{ .symbol = sym_return_statement, .state = 16 },
    .{ .symbol = sym_simple_statements, .state = 54 },
    .{ .symbol = sym_statement, .state = 52 },
};
const s69_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
};
const s70_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_False, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 7, .production_id = 14 } } },
    .{ .symbol = sym_None, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 7, .production_id = 14 } } },
    .{ .symbol = sym_True, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 7, .production_id = 14 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 7, .production_id = 14 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 7, .production_id = 14 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 7, .production_id = 14 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 7, .production_id = 14 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 7, .production_id = 14 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 7, .production_id = 14 } } },
    .{ .symbol = sym_pass, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 7, .production_id = 14 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 7, .production_id = 14 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 7, .production_id = 14 } } },
};

const parse_states: []const tables_mod.ParseState = &.{
    .{ .actions = s0_actions, .gotos = s0_gotos }, // 0
    .{ .actions = s1_actions }, // 1
    .{ .actions = s2_actions }, // 2
    .{ .actions = s3_actions, .gotos = s3_gotos }, // 3
    .{ .actions = s4_actions }, // 4
    .{ .actions = s5_actions }, // 5
    .{ .actions = s6_actions }, // 6
    .{ .actions = s7_actions }, // 7
    .{ .actions = s8_actions }, // 8
    .{ .actions = s9_actions }, // 9
    .{ .actions = s10_actions }, // 10
    .{ .actions = s11_actions }, // 11
    .{ .actions = s12_actions, .gotos = s12_gotos }, // 12
    .{ .actions = s13_actions }, // 13
    .{ .actions = s14_actions }, // 14
    .{ .actions = s15_actions }, // 15
    .{ .actions = s16_actions }, // 16
    .{ .actions = s17_actions }, // 17
    .{ .actions = s18_actions }, // 18
    .{ .actions = s19_actions }, // 19
    .{ .actions = s20_actions }, // 20
    .{ .actions = s21_actions }, // 21
    .{ .actions = s22_actions }, // 22
    .{ .actions = s23_actions }, // 23
    .{ .actions = s24_actions }, // 24
    .{ .actions = s25_actions }, // 25
    .{ .actions = s26_actions }, // 26
    .{ .actions = s27_actions }, // 27
    .{ .actions = s28_actions }, // 28
    .{ .actions = s29_actions, .gotos = s29_gotos }, // 29
    .{ .actions = s30_actions, .gotos = s30_gotos }, // 30
    .{ .actions = s31_actions }, // 31
    .{ .actions = s32_actions }, // 32
    .{ .actions = s33_actions, .gotos = s33_gotos }, // 33
    .{ .actions = s34_actions, .gotos = s34_gotos }, // 34
    .{ .actions = s35_actions, .gotos = s35_gotos }, // 35
    .{ .actions = s36_actions, .gotos = s36_gotos }, // 36
    .{ .actions = s37_actions, .gotos = s37_gotos }, // 37
    .{ .actions = s38_actions }, // 38
    .{ .actions = s39_actions }, // 39
    .{ .actions = s40_actions }, // 40
    .{ .actions = s41_actions }, // 41
    .{ .actions = s42_actions }, // 42
    .{ .actions = s43_actions }, // 43
    .{ .actions = s44_actions }, // 44
    .{ .actions = s45_actions }, // 45
    .{ .actions = s46_actions }, // 46
    .{ .actions = s47_actions }, // 47
    .{ .actions = s48_actions }, // 48
    .{ .actions = s49_actions }, // 49
    .{ .actions = s50_actions }, // 50
    .{ .actions = s51_actions, .gotos = s51_gotos }, // 51
    .{ .actions = s52_actions }, // 52
    .{ .actions = s53_actions }, // 53
    .{ .actions = s54_actions }, // 54
    .{ .actions = s55_actions }, // 55
    .{ .actions = s56_actions, .gotos = s56_gotos }, // 56
    .{ .actions = s57_actions }, // 57
    .{ .actions = s58_actions, .gotos = s58_gotos }, // 58
    .{ .actions = s59_actions }, // 59
    .{ .actions = s60_actions }, // 60
    .{ .actions = s61_actions, .gotos = s61_gotos }, // 61
    .{ .actions = s62_actions }, // 62
    .{ .actions = s63_actions }, // 63
    .{ .actions = s64_actions }, // 64
    .{ .actions = s65_actions }, // 65
    .{ .actions = s66_actions, .gotos = s66_gotos }, // 66
    .{ .actions = s67_actions }, // 67
    .{ .actions = s68_actions, .gotos = s68_gotos }, // 68
    .{ .actions = s69_actions }, // 69
    .{ .actions = s70_actions }, // 70
};

const field_names: []const []const u8 = &.{ "name", "parameters", "body", "superclasses", "argument", "left", "right", "function", "arguments" };
const field_productions: []const fields_mod.FieldProduction = &.{
    .{ .production_id = 9, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "parameters", .child_index = 3 }, .{ .name = "body", .child_index = 6 } } },
    .{ .production_id = 10, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 5 } } },
    .{ .production_id = 13, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 3 } } },
    .{ .production_id = 14, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "superclasses", .child_index = 3 }, .{ .name = "body", .child_index = 6 } } },
    .{ .production_id = 18, .bindings = &.{.{ .name = "argument", .child_index = 1 }} },
    .{ .production_id = 26, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 27, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 28, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 29, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 30, .bindings = &.{ .{ .name = "function", .child_index = 0 }, .{ .name = "arguments", .child_index = 2 } } },
    .{ .production_id = 31, .bindings = &.{.{ .name = "function", .child_index = 0 }} },
};

pub const language: Language = .{
    .metadata = .{
        .name = "python",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.3",
        .symbol_count = 42,
        .state_count = 71,
        .field_count = 9,
    },
    .symbols = symbol_table,
    .token_matchers = token_matchers,
    .extra_symbols = extra_symbols,
    .table = .{
        .states = parse_states,
        .start_state = 0,
        .end_symbol = sym_end,
        .error_symbol = sym_ERROR,
    },
    .fields = .{
        .names = field_names,
        .productions = field_productions,
    },
    .external_scanner = scanner.external_scanner,
};

pub fn getLanguage() Language {
    return language;
}

pub const scanner = @import("scanner.zig");
pub const grammar_json = @embedFile("grammar.json");
pub const node_types_json = @embedFile("node-types.json");

test "parser: python table verification" {
    try std.testing.expectEqualStrings("python", language.metadata.name);
    try std.testing.expect(language.metadata.symbol_count > 0);
    try std.testing.expect(language.table.stateCount() > 0);
}

test "parser: python node types verification" {
    var nt = try treesitter.NodeTypes.parseJSON(std.testing.allocator, node_types_json);
    defer nt.deinit();
    try std.testing.expect(nt.findType("module") != null);
}

test "parser: python grammar json verification" {
    var dsl = treesitter.DSLParser.init(std.testing.allocator);
    var g = try dsl.parseJSON(grammar_json);
    defer g.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("python", g.name);
    try std.testing.expect(g.rules.items.len > 0);
}

test "parser: python genuine program parsing 1" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    var lang = language;
    var scan_state = scanner.ScanState.init(std.testing.allocator);
    defer scan_state.deinit();
    lang.external_scanner.?.payload = &scan_state;
    try parser.setLanguage(lang);
    var tree = try parser.parseString("def add(x, y):\n    return x + y\n");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("module", root.nodeType());
}

test "parser: python genuine program parsing 2" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    var lang = language;
    var scan_state = scanner.ScanState.init(std.testing.allocator);
    defer scan_state.deinit();
    lang.external_scanner.?.payload = &scan_state;
    try parser.setLanguage(lang);
    var tree = try parser.parseString("class Foo:\n    pass\n");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("module", root.nodeType());
}
