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
pub const sym_doctype_start: u16 = 1;
pub const sym_tag_close_start: u16 = 2;
pub const sym_self_closing_end: u16 = 3;
pub const sym_tag_start: u16 = 4;
pub const sym_tag_end: u16 = 5;
pub const sym_eq: u16 = 6;
pub const sym_identifier: u16 = 7;
pub const sym_attribute_value: u16 = 8;
pub const sym_text: u16 = 9;
pub const sym_whitespace: u16 = 10;
pub const sym_document: u16 = 11;
pub const sym_elements: u16 = 12;
pub const sym_element: u16 = 13;
pub const sym_doctype: u16 = 14;
pub const sym_tag_element: u16 = 15;
pub const sym_start_tag: u16 = 16;
pub const sym_end_tag: u16 = 17;
pub const sym_self_closing_tag: u16 = 18;
pub const sym_attributes: u16 = 19;
pub const sym_attribute: u16 = 20;
pub const sym_ERROR: u16 = 21;

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
    return null;
}

const symbol_table: []const symbols_mod.SymbolInfo = &.{
    .{ .id = sym_end, .name = "end", .kind = .end, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_doctype_start, .name = "<!DOCTYPE", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_tag_close_start, .name = "</", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_self_closing_end, .name = "/>", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_tag_start, .name = "<", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_tag_end, .name = ">", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_eq, .name = "=", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_identifier, .name = "identifier", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_attribute_value, .name = "attribute_value", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_text, .name = "text", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = true, .named = false, .extra = true } },
    .{ .id = sym_document, .name = "document", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_elements, .name = "elements", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_element, .name = "element", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_doctype, .name = "doctype", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_tag_element, .name = "tag_element", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_start_tag, .name = "start_tag", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_end_tag, .name = "end_tag", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_self_closing_tag, .name = "self_closing_tag", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_attributes, .name = "attributes", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_attribute, .name = "attribute", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_ERROR, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const token_matchers: []const language_mod.TokenMatcher = &.{
    .{ .symbol = sym_doctype_start, .match = matchLiteral("<!DOCTYPE") },
    .{ .symbol = sym_tag_close_start, .match = matchLiteral("</") },
    .{ .symbol = sym_self_closing_end, .match = matchLiteral("/>") },
    .{ .symbol = sym_tag_start, .match = language_mod.matchChar('<') },
    .{ .symbol = sym_tag_end, .match = language_mod.matchChar('>') },
    .{ .symbol = sym_eq, .match = language_mod.matchChar('=') },
    .{ .symbol = sym_identifier, .match = matchIdentifier },
    .{ .symbol = sym_attribute_value, .match = matchString },
    .{ .symbol = sym_whitespace, .match = language_mod.matchWhitespace },
};

const extra_symbols: []const u16 = &.{sym_whitespace};

const s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .shift = 1 } },
    .{ .symbol = sym_tag_start, .action = .{ .shift = 2 } },
    .{ .symbol = sym_text, .action = .{ .shift = 3 } },
};
const s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_doctype, .state = 7 },
    .{ .symbol = sym_document, .state = 4 },
    .{ .symbol = sym_element, .state = 6 },
    .{ .symbol = sym_elements, .state = 5 },
    .{ .symbol = sym_self_closing_tag, .state = 10 },
    .{ .symbol = sym_start_tag, .state = 9 },
    .{ .symbol = sym_tag_element, .state = 8 },
};
const s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 11 } },
};
const s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 12 } },
};
const s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 6 } } },
};
const s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .accept },
};
const s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .shift = 1 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_document, .child_count = 1, .production_id = 1 } } },
    .{ .symbol = sym_tag_start, .action = .{ .shift = 2 } },
    .{ .symbol = sym_text, .action = .{ .shift = 3 } },
};
const s5_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_doctype, .state = 7 },
    .{ .symbol = sym_element, .state = 13 },
    .{ .symbol = sym_self_closing_tag, .state = 10 },
    .{ .symbol = sym_start_tag, .state = 9 },
    .{ .symbol = sym_tag_element, .state = 8 },
};
const s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 1, .production_id = 2 } } },
};
const s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 4 } } },
};
const s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_element, .child_count = 1, .production_id = 5 } } },
};
const s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .shift = 1 } },
    .{ .symbol = sym_tag_close_start, .action = .{ .shift = 14 } },
    .{ .symbol = sym_tag_start, .action = .{ .shift = 2 } },
    .{ .symbol = sym_text, .action = .{ .shift = 3 } },
};
const s9_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_doctype, .state = 7 },
    .{ .symbol = sym_element, .state = 6 },
    .{ .symbol = sym_elements, .state = 15 },
    .{ .symbol = sym_end_tag, .state = 16 },
    .{ .symbol = sym_self_closing_tag, .state = 10 },
    .{ .symbol = sym_start_tag, .state = 9 },
    .{ .symbol = sym_tag_element, .state = 8 },
};
const s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 1, .production_id = 10 } } },
};
const s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_tag_end, .action = .{ .shift = 17 } },
};
const s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 20 } },
    .{ .symbol = sym_self_closing_end, .action = .{ .shift = 18 } },
    .{ .symbol = sym_tag_end, .action = .{ .shift = 19 } },
};
const s12_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_attribute, .state = 22 },
    .{ .symbol = sym_attributes, .state = 21 },
};
const s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_elements, .child_count = 2, .production_id = 3 } } },
};
const s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 23 } },
};
const s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .shift = 1 } },
    .{ .symbol = sym_tag_close_start, .action = .{ .shift = 14 } },
    .{ .symbol = sym_tag_start, .action = .{ .shift = 2 } },
    .{ .symbol = sym_text, .action = .{ .shift = 3 } },
};
const s15_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_doctype, .state = 7 },
    .{ .symbol = sym_element, .state = 13 },
    .{ .symbol = sym_end_tag, .state = 24 },
    .{ .symbol = sym_self_closing_tag, .state = 10 },
    .{ .symbol = sym_start_tag, .state = 9 },
    .{ .symbol = sym_tag_element, .state = 8 },
};
const s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 2, .production_id = 9 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 2, .production_id = 9 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 2, .production_id = 9 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 2, .production_id = 9 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 2, .production_id = 9 } } },
};
const s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_doctype, .child_count = 3, .production_id = 7 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_doctype, .child_count = 3, .production_id = 7 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_doctype, .child_count = 3, .production_id = 7 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_doctype, .child_count = 3, .production_id = 7 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_doctype, .child_count = 3, .production_id = 7 } } },
};
const s18_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_self_closing_tag, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_self_closing_tag, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_self_closing_tag, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_self_closing_tag, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_self_closing_tag, .child_count = 3, .production_id = 15 } } },
};
const s19_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_start_tag, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_start_tag, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_start_tag, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_start_tag, .child_count = 3, .production_id = 12 } } },
};
const s20_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eq, .action = .{ .shift = 25 } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_attribute, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_self_closing_end, .action = .{ .reduce = .{ .symbol = sym_attribute, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_tag_end, .action = .{ .reduce = .{ .symbol = sym_attribute, .child_count = 1, .production_id = 19 } } },
};
const s21_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 20 } },
    .{ .symbol = sym_self_closing_end, .action = .{ .shift = 26 } },
    .{ .symbol = sym_tag_end, .action = .{ .shift = 27 } },
};
const s21_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_attribute, .state = 28 },
};
const s22_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_attributes, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_self_closing_end, .action = .{ .reduce = .{ .symbol = sym_attributes, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_tag_end, .action = .{ .reduce = .{ .symbol = sym_attributes, .child_count = 1, .production_id = 16 } } },
};
const s23_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_tag_end, .action = .{ .shift = 29 } },
};
const s24_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 3, .production_id = 8 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 3, .production_id = 8 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 3, .production_id = 8 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 3, .production_id = 8 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_tag_element, .child_count = 3, .production_id = 8 } } },
};
const s25_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_attribute_value, .action = .{ .shift = 30 } },
};
const s26_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_self_closing_tag, .child_count = 4, .production_id = 14 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_self_closing_tag, .child_count = 4, .production_id = 14 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_self_closing_tag, .child_count = 4, .production_id = 14 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_self_closing_tag, .child_count = 4, .production_id = 14 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_self_closing_tag, .child_count = 4, .production_id = 14 } } },
};
const s27_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_start_tag, .child_count = 4, .production_id = 11 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_start_tag, .child_count = 4, .production_id = 11 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_start_tag, .child_count = 4, .production_id = 11 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_start_tag, .child_count = 4, .production_id = 11 } } },
};
const s28_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_attributes, .child_count = 2, .production_id = 17 } } },
    .{ .symbol = sym_self_closing_end, .action = .{ .reduce = .{ .symbol = sym_attributes, .child_count = 2, .production_id = 17 } } },
    .{ .symbol = sym_tag_end, .action = .{ .reduce = .{ .symbol = sym_attributes, .child_count = 2, .production_id = 17 } } },
};
const s29_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_doctype_start, .action = .{ .reduce = .{ .symbol = sym_end_tag, .child_count = 3, .production_id = 13 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_end_tag, .child_count = 3, .production_id = 13 } } },
    .{ .symbol = sym_tag_close_start, .action = .{ .reduce = .{ .symbol = sym_end_tag, .child_count = 3, .production_id = 13 } } },
    .{ .symbol = sym_tag_start, .action = .{ .reduce = .{ .symbol = sym_end_tag, .child_count = 3, .production_id = 13 } } },
    .{ .symbol = sym_text, .action = .{ .reduce = .{ .symbol = sym_end_tag, .child_count = 3, .production_id = 13 } } },
};
const s30_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_attribute, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_self_closing_end, .action = .{ .reduce = .{ .symbol = sym_attribute, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_tag_end, .action = .{ .reduce = .{ .symbol = sym_attribute, .child_count = 3, .production_id = 18 } } },
};

const parse_states: []const tables_mod.ParseState = &.{
    .{ .actions = s0_actions, .gotos = s0_gotos }, // 0
    .{ .actions = s1_actions }, // 1
    .{ .actions = s2_actions }, // 2
    .{ .actions = s3_actions }, // 3
    .{ .actions = s4_actions }, // 4
    .{ .actions = s5_actions, .gotos = s5_gotos }, // 5
    .{ .actions = s6_actions }, // 6
    .{ .actions = s7_actions }, // 7
    .{ .actions = s8_actions }, // 8
    .{ .actions = s9_actions, .gotos = s9_gotos }, // 9
    .{ .actions = s10_actions }, // 10
    .{ .actions = s11_actions }, // 11
    .{ .actions = s12_actions, .gotos = s12_gotos }, // 12
    .{ .actions = s13_actions }, // 13
    .{ .actions = s14_actions }, // 14
    .{ .actions = s15_actions, .gotos = s15_gotos }, // 15
    .{ .actions = s16_actions }, // 16
    .{ .actions = s17_actions }, // 17
    .{ .actions = s18_actions }, // 18
    .{ .actions = s19_actions }, // 19
    .{ .actions = s20_actions }, // 20
    .{ .actions = s21_actions, .gotos = s21_gotos }, // 21
    .{ .actions = s22_actions }, // 22
    .{ .actions = s23_actions }, // 23
    .{ .actions = s24_actions }, // 24
    .{ .actions = s25_actions }, // 25
    .{ .actions = s26_actions }, // 26
    .{ .actions = s27_actions }, // 27
    .{ .actions = s28_actions }, // 28
    .{ .actions = s29_actions }, // 29
    .{ .actions = s30_actions }, // 30
};

const field_names: []const []const u8 = &.{ "name", "value" };
const field_productions: []const fields_mod.FieldProduction = &.{
    .{ .production_id = 11, .bindings = &.{.{ .name = "name", .child_index = 1 }} },
    .{ .production_id = 12, .bindings = &.{.{ .name = "name", .child_index = 1 }} },
    .{ .production_id = 13, .bindings = &.{.{ .name = "name", .child_index = 1 }} },
    .{ .production_id = 14, .bindings = &.{.{ .name = "name", .child_index = 1 }} },
    .{ .production_id = 15, .bindings = &.{.{ .name = "name", .child_index = 1 }} },
    .{ .production_id = 18, .bindings = &.{ .{ .name = "name", .child_index = 0 }, .{ .name = "value", .child_index = 2 } } },
    .{ .production_id = 19, .bindings = &.{.{ .name = "name", .child_index = 0 }} },
};

pub const language: Language = .{
    .metadata = .{
        .name = "html",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.3",
        .symbol_count = 22,
        .state_count = 31,
        .field_count = 2,
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

test "parser: html table verification" {
    try std.testing.expectEqualStrings("html", language.metadata.name);
    try std.testing.expect(language.metadata.symbol_count > 0);
    try std.testing.expect(language.table.stateCount() > 0);
}

test "parser: html node types verification" {
    var nt = try treesitter.NodeTypes.parseJSON(std.testing.allocator, node_types_json);
    defer nt.deinit();
    try std.testing.expect(nt.findType("document") != null);
}

test "parser: html grammar json verification" {
    var dsl = treesitter.DSLParser.init(std.testing.allocator);
    var g = try dsl.parseJSON(grammar_json);
    defer g.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("html", g.name);
    try std.testing.expect(g.rules.items.len > 0);
}

test "parser: html genuine program parsing 1" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    var lang = language;
    var scan_state = scanner.ScanState.init(std.testing.allocator);
    defer scan_state.deinit();
    lang.external_scanner.?.payload = &scan_state;
    try parser.setLanguage(lang);
    var tree = try parser.parseString("<!DOCTYPE html><html><body class=\"container\">Hello</body></html>");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("document", root.nodeType());
}
