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
pub const sym_php_tag: u16 = 1;
pub const sym_function: u16 = 2;
pub const sym_class: u16 = 3;
pub const sym_echo: u16 = 4;
pub const sym_return: u16 = 5;
pub const sym_semi: u16 = 6;
pub const sym_comma: u16 = 7;
pub const sym_lparen: u16 = 8;
pub const sym_rparen: u16 = 9;
pub const sym_lbrace: u16 = 10;
pub const sym_rbrace: u16 = 11;
pub const sym_eq: u16 = 12;
pub const sym_plus: u16 = 13;
pub const sym_dot: u16 = 14;
pub const sym_variable_name: u16 = 15;
pub const sym_identifier: u16 = 16;
pub const sym_integer: u16 = 17;
pub const sym_string: u16 = 18;
pub const sym_whitespace: u16 = 19;
pub const sym_comment: u16 = 20;
pub const sym_program: u16 = 21;
pub const sym_statements: u16 = 22;
pub const sym_statement: u16 = 23;
pub const sym_function_definition: u16 = 24;
pub const sym_parameters: u16 = 25;
pub const sym_class_definition: u16 = 26;
pub const sym_echo_statement: u16 = 27;
pub const sym_return_statement: u16 = 28;
pub const sym_expression: u16 = 29;
pub const sym_binary_expression: u16 = 30;
pub const sym_primary: u16 = 31;
pub const sym_ERROR: u16 = 32;

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
    .{ .id = sym_php_tag, .name = "<?php", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_function, .name = "function", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_class, .name = "class", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_echo, .name = "echo", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_return, .name = "return", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_semi, .name = ";", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_comma, .name = ",", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lparen, .name = "(", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rparen, .name = ")", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lbrace, .name = "{", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rbrace, .name = "}", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_eq, .name = "=", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_plus, .name = "+", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_dot, .name = ".", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_variable_name, .name = "variable_name", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_identifier, .name = "identifier", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_integer, .name = "integer", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_string, .name = "string", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = true, .named = false, .extra = true } },
    .{ .id = sym_comment, .name = "comment", .kind = .terminal, .metadata = .{ .visible = true, .named = true, .extra = true } },
    .{ .id = sym_program, .name = "program", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statements, .name = "statements", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statement, .name = "statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_function_definition, .name = "function_definition", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_parameters, .name = "parameters", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_class_definition, .name = "class_definition", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_echo_statement, .name = "echo_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_return_statement, .name = "return_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expression, .name = "expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_binary_expression, .name = "binary_expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_primary, .name = "primary", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_ERROR, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const token_matchers: []const language_mod.TokenMatcher = &.{
    .{ .symbol = sym_php_tag, .match = matchLiteral("<?php") },
    .{ .symbol = sym_function, .match = matchKeyword("function") },
    .{ .symbol = sym_class, .match = matchKeyword("class") },
    .{ .symbol = sym_echo, .match = matchKeyword("echo") },
    .{ .symbol = sym_return, .match = matchKeyword("return") },
    .{ .symbol = sym_semi, .match = language_mod.matchChar(';') },
    .{ .symbol = sym_comma, .match = language_mod.matchChar(',') },
    .{ .symbol = sym_lparen, .match = language_mod.matchChar('(') },
    .{ .symbol = sym_rparen, .match = language_mod.matchChar(')') },
    .{ .symbol = sym_lbrace, .match = language_mod.matchChar('{') },
    .{ .symbol = sym_rbrace, .match = language_mod.matchChar('}') },
    .{ .symbol = sym_eq, .match = language_mod.matchChar('=') },
    .{ .symbol = sym_plus, .match = language_mod.matchChar('+') },
    .{ .symbol = sym_dot, .match = language_mod.matchChar('.') },
    .{ .symbol = sym_variable_name, .match = struct {
        fn match(source: []const u8, start: usize) ?usize {
            if (start >= source.len or source[start] != '$') return null;
            if (start + 1 >= source.len or (!std.ascii.isAlphabetic(source[start + 1]) and source[start + 1] != '_')) return null;
            var i = start + 2;
            while (i < source.len and (std.ascii.isAlphanumeric(source[i]) or source[i] == '_')) : (i += 1) {}
            return i - start;
        }
    }.match },
    .{ .symbol = sym_identifier, .match = matchIdentifier },
    .{ .symbol = sym_integer, .match = matchNumber },
    .{ .symbol = sym_string, .match = matchString },
    .{ .symbol = sym_whitespace, .match = language_mod.matchWhitespace },
    .{ .symbol = sym_comment, .match = matchComment },
};

const extra_symbols: []const u16 = &.{ sym_whitespace, sym_comment };

const s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_php_tag, .action = .{ .shift = 1 } },
};
const s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_program, .state = 2 },
};
const s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 4 } },
    .{ .symbol = sym_echo, .action = .{ .shift = 5 } },
    .{ .symbol = sym_function, .action = .{ .shift = 3 } },
    .{ .symbol = sym_return, .action = .{ .shift = 6 } },
};
const s1_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_definition, .state = 10 },
    .{ .symbol = sym_echo_statement, .state = 11 },
    .{ .symbol = sym_function_definition, .state = 9 },
    .{ .symbol = sym_return_statement, .state = 12 },
    .{ .symbol = sym_statement, .state = 8 },
    .{ .symbol = sym_statements, .state = 7 },
};
const s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .accept },
};
const s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
};
const s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 14 } },
};
const s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 16 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 17 } },
    .{ .symbol = sym_string, .action = .{ .shift = 18 } },
    .{ .symbol = sym_variable_name, .action = .{ .shift = 15 } },
};
const s5_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 20 },
    .{ .symbol = sym_expression, .state = 19 },
    .{ .symbol = sym_primary, .state = 21 },
};
const s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 16 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 17 } },
    .{ .symbol = sym_string, .action = .{ .shift = 18 } },
    .{ .symbol = sym_variable_name, .action = .{ .shift = 15 } },
};
const s6_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 20 },
    .{ .symbol = sym_expression, .state = 22 },
    .{ .symbol = sym_primary, .state = 21 },
};
const s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 4 } },
    .{ .symbol = sym_echo, .action = .{ .shift = 5 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_program, .child_count = 2, .production_id = 1 } } },
    .{ .symbol = sym_function, .action = .{ .shift = 3 } },
    .{ .symbol = sym_return, .action = .{ .shift = 6 } },
};
const s7_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_definition, .state = 10 },
    .{ .symbol = sym_echo_statement, .state = 11 },
    .{ .symbol = sym_function_definition, .state = 9 },
    .{ .symbol = sym_return_statement, .state = 12 },
    .{ .symbol = sym_statement, .state = 23 },
};
const s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_echo, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
};
const s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_echo, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
};
const s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_echo, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
};
const s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_echo, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
};
const s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_echo, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
};
const s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lparen, .action = .{ .shift = 24 } },
};
const s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 25 } },
};
const s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 19 } } },
};
const s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 20 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 20 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 20 } } },
};
const s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
};
const s18_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
};
const s19_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .shift = 28 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 27 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 26 } },
};
const s20_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 15 } } },
};
const s21_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 16 } } },
};
const s22_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .shift = 28 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 27 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 29 } },
};
const s23_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_echo, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
};
const s24_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_rparen, .action = .{ .shift = 30 } },
    .{ .symbol = sym_variable_name, .action = .{ .shift = 31 } },
};
const s24_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_parameters, .state = 32 },
};
const s25_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 4 } },
    .{ .symbol = sym_echo, .action = .{ .shift = 5 } },
    .{ .symbol = sym_function, .action = .{ .shift = 3 } },
    .{ .symbol = sym_return, .action = .{ .shift = 6 } },
};
const s25_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_definition, .state = 10 },
    .{ .symbol = sym_echo_statement, .state = 11 },
    .{ .symbol = sym_function_definition, .state = 9 },
    .{ .symbol = sym_return_statement, .state = 12 },
    .{ .symbol = sym_statement, .state = 8 },
    .{ .symbol = sym_statements, .state = 33 },
};
const s26_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_echo_statement, .child_count = 3, .production_id = 13 } } },
    .{ .symbol = sym_echo, .action = .{ .reduce = .{ .symbol = sym_echo_statement, .child_count = 3, .production_id = 13 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_echo_statement, .child_count = 3, .production_id = 13 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_echo_statement, .child_count = 3, .production_id = 13 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_echo_statement, .child_count = 3, .production_id = 13 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_echo_statement, .child_count = 3, .production_id = 13 } } },
};
const s27_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 16 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 17 } },
    .{ .symbol = sym_string, .action = .{ .shift = 18 } },
    .{ .symbol = sym_variable_name, .action = .{ .shift = 15 } },
};
const s27_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary, .state = 34 },
};
const s28_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 16 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 17 } },
    .{ .symbol = sym_string, .action = .{ .shift = 18 } },
    .{ .symbol = sym_variable_name, .action = .{ .shift = 15 } },
};
const s28_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary, .state = 35 },
};
const s29_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 14 } } },
    .{ .symbol = sym_echo, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 14 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 14 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 14 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 14 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 14 } } },
};
const s30_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 36 } },
};
const s31_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameters, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameters, .child_count = 1, .production_id = 10 } } },
};
const s32_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 37 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 38 } },
};
const s33_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 4 } },
    .{ .symbol = sym_echo, .action = .{ .shift = 5 } },
    .{ .symbol = sym_function, .action = .{ .shift = 3 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 39 } },
    .{ .symbol = sym_return, .action = .{ .shift = 6 } },
};
const s33_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_definition, .state = 10 },
    .{ .symbol = sym_echo_statement, .state = 11 },
    .{ .symbol = sym_function_definition, .state = 9 },
    .{ .symbol = sym_return_statement, .state = 12 },
    .{ .symbol = sym_statement, .state = 23 },
};
const s34_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 17 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 17 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 17 } } },
};
const s35_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 18 } } },
};
const s36_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 4 } },
    .{ .symbol = sym_echo, .action = .{ .shift = 5 } },
    .{ .symbol = sym_function, .action = .{ .shift = 3 } },
    .{ .symbol = sym_return, .action = .{ .shift = 6 } },
};
const s36_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_definition, .state = 10 },
    .{ .symbol = sym_echo_statement, .state = 11 },
    .{ .symbol = sym_function_definition, .state = 9 },
    .{ .symbol = sym_return_statement, .state = 12 },
    .{ .symbol = sym_statement, .state = 8 },
    .{ .symbol = sym_statements, .state = 40 },
};
const s37_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_variable_name, .action = .{ .shift = 41 } },
};
const s38_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 42 } },
};
const s39_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 5, .production_id = 12 } } },
    .{ .symbol = sym_echo, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 5, .production_id = 12 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 5, .production_id = 12 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 5, .production_id = 12 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 5, .production_id = 12 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 5, .production_id = 12 } } },
};
const s40_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 4 } },
    .{ .symbol = sym_echo, .action = .{ .shift = 5 } },
    .{ .symbol = sym_function, .action = .{ .shift = 3 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 43 } },
    .{ .symbol = sym_return, .action = .{ .shift = 6 } },
};
const s40_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_definition, .state = 10 },
    .{ .symbol = sym_echo_statement, .state = 11 },
    .{ .symbol = sym_function_definition, .state = 9 },
    .{ .symbol = sym_return_statement, .state = 12 },
    .{ .symbol = sym_statement, .state = 23 },
};
const s41_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameters, .child_count = 3, .production_id = 11 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameters, .child_count = 3, .production_id = 11 } } },
};
const s42_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 4 } },
    .{ .symbol = sym_echo, .action = .{ .shift = 5 } },
    .{ .symbol = sym_function, .action = .{ .shift = 3 } },
    .{ .symbol = sym_return, .action = .{ .shift = 6 } },
};
const s42_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_definition, .state = 10 },
    .{ .symbol = sym_echo_statement, .state = 11 },
    .{ .symbol = sym_function_definition, .state = 9 },
    .{ .symbol = sym_return_statement, .state = 12 },
    .{ .symbol = sym_statement, .state = 8 },
    .{ .symbol = sym_statements, .state = 44 },
};
const s43_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_echo, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 7, .production_id = 9 } } },
};
const s44_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 4 } },
    .{ .symbol = sym_echo, .action = .{ .shift = 5 } },
    .{ .symbol = sym_function, .action = .{ .shift = 3 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 45 } },
    .{ .symbol = sym_return, .action = .{ .shift = 6 } },
};
const s44_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_definition, .state = 10 },
    .{ .symbol = sym_echo_statement, .state = 11 },
    .{ .symbol = sym_function_definition, .state = 9 },
    .{ .symbol = sym_return_statement, .state = 12 },
    .{ .symbol = sym_statement, .state = 23 },
};
const s45_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 8, .production_id = 8 } } },
    .{ .symbol = sym_echo, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 8, .production_id = 8 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 8, .production_id = 8 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 8, .production_id = 8 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 8, .production_id = 8 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 8, .production_id = 8 } } },
};

const parse_states: []const tables_mod.ParseState = &.{
    .{ .actions = s0_actions, .gotos = s0_gotos }, // 0
    .{ .actions = s1_actions, .gotos = s1_gotos }, // 1
    .{ .actions = s2_actions }, // 2
    .{ .actions = s3_actions }, // 3
    .{ .actions = s4_actions }, // 4
    .{ .actions = s5_actions, .gotos = s5_gotos }, // 5
    .{ .actions = s6_actions, .gotos = s6_gotos }, // 6
    .{ .actions = s7_actions, .gotos = s7_gotos }, // 7
    .{ .actions = s8_actions }, // 8
    .{ .actions = s9_actions }, // 9
    .{ .actions = s10_actions }, // 10
    .{ .actions = s11_actions }, // 11
    .{ .actions = s12_actions }, // 12
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
    .{ .actions = s24_actions, .gotos = s24_gotos }, // 24
    .{ .actions = s25_actions, .gotos = s25_gotos }, // 25
    .{ .actions = s26_actions }, // 26
    .{ .actions = s27_actions, .gotos = s27_gotos }, // 27
    .{ .actions = s28_actions, .gotos = s28_gotos }, // 28
    .{ .actions = s29_actions }, // 29
    .{ .actions = s30_actions }, // 30
    .{ .actions = s31_actions }, // 31
    .{ .actions = s32_actions }, // 32
    .{ .actions = s33_actions, .gotos = s33_gotos }, // 33
    .{ .actions = s34_actions }, // 34
    .{ .actions = s35_actions }, // 35
    .{ .actions = s36_actions, .gotos = s36_gotos }, // 36
    .{ .actions = s37_actions }, // 37
    .{ .actions = s38_actions }, // 38
    .{ .actions = s39_actions }, // 39
    .{ .actions = s40_actions, .gotos = s40_gotos }, // 40
    .{ .actions = s41_actions }, // 41
    .{ .actions = s42_actions, .gotos = s42_gotos }, // 42
    .{ .actions = s43_actions }, // 43
    .{ .actions = s44_actions, .gotos = s44_gotos }, // 44
    .{ .actions = s45_actions }, // 45
};

const field_names: []const []const u8 = &.{ "name", "parameters", "body", "argument", "left", "right" };
const field_productions: []const fields_mod.FieldProduction = &.{
    .{ .production_id = 8, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "parameters", .child_index = 3 }, .{ .name = "body", .child_index = 6 } } },
    .{ .production_id = 9, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 5 } } },
    .{ .production_id = 12, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 3 } } },
    .{ .production_id = 13, .bindings = &.{.{ .name = "argument", .child_index = 1 }} },
    .{ .production_id = 14, .bindings = &.{.{ .name = "argument", .child_index = 1 }} },
    .{ .production_id = 17, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 18, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
};

pub const language: Language = .{
    .metadata = .{
        .name = "php",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.3",
        .symbol_count = 33,
        .state_count = 46,
        .field_count = 6,
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
    .external_scanner = null,
};

pub fn getLanguage() Language {
    return language;
}

pub const scanner = @import("scanner.zig");
pub const grammar_json = @embedFile("grammar.json");
pub const node_types_json = @embedFile("node-types.json");

test "parser: php table verification" {
    try std.testing.expectEqualStrings("php", language.metadata.name);
    try std.testing.expect(language.metadata.symbol_count > 0);
    try std.testing.expect(language.table.stateCount() > 0);
}

test "parser: php node types verification" {
    var nt = try treesitter.NodeTypes.parseJSON(std.testing.allocator, node_types_json);
    defer nt.deinit();
    try std.testing.expect(nt.findType("program") != null);
}

test "parser: php grammar json verification" {
    var dsl = treesitter.DSLParser.init(std.testing.allocator);
    var g = try dsl.parseJSON(grammar_json);
    defer g.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("php", g.name);
    try std.testing.expect(g.rules.items.len > 0);
}

test "parser: php genuine program parsing 1" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("<?php function add($a, $b) { return $a + $b; }");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
}
