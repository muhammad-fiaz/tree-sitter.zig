const std = @import("std");
const symbols_mod = @import("symbols.zig");
const tables_mod = @import("tables.zig");
const fields_mod = @import("fields.zig");
const aliases_mod = @import("aliases.zig");
const metadata_mod = @import("metadata.zig");

pub const symbols = @import("symbols.zig");
pub const tables = @import("tables.zig");
pub const fields = @import("fields.zig");
pub const aliases = @import("aliases.zig");
pub const metadata = @import("metadata.zig");

pub const TokenMatchFn = *const fn (source: []const u8, start: usize) ?usize;

pub const TokenMatcher = struct {
    symbol: u16,
    match: TokenMatchFn,
};

pub const ExternalScanner = struct {
    payload: ?*anyopaque = null,
    scan: *const fn (payload: ?*anyopaque, source: []const u8, start: usize, valid_symbols: []const bool) ?ExternalToken,
    reset: ?*const fn (payload: ?*anyopaque) void = null,

    pub const ExternalToken = struct {
        symbol: u16,
        length: usize,
    };
};

pub const Language = struct {
    metadata: metadata_mod.Metadata = .{},
    symbols: []const symbols_mod.SymbolInfo = &.{},
    token_matchers: []const TokenMatcher = &.{},
    extra_symbols: []const u16 = &.{},
    word_token: u16 = 0,
    table: tables_mod.ParseTable = .{},
    fields: fields_mod.FieldMap = .{},
    aliases: aliases_mod.AliasMap = .{},
    supertypes: []const u16 = &.{},
    /// Maps a supertype symbol to the subtype symbols it covers. Used
    /// by query matching: a pattern naming a supertype also matches any
    /// of its listed subtypes (subtype expansion).
    supertype_map: []const SupertypeEntry = &.{},
    external_scanner: ?ExternalScanner = null,

    pub const Error = error{
        IncompatibleAbiVersion,
        InvalidSymbol,
    };

    pub fn symbolCount(self: Language) usize {
        return self.symbols.len;
    }

    pub fn validate(self: Language) Error!void {
        if (!self.metadata.isCompatible()) return error.IncompatibleAbiVersion;
    }

    pub fn symbolInfo(self: Language, id: u16) ?symbols_mod.SymbolInfo {
        for (self.symbols) |s| {
            if (s.id == id) return s;
        }
        return null;
    }

    pub fn symbolName(self: Language, id: u16) []const u8 {
        return if (self.symbolInfo(id)) |info| info.name else "(unknown)";
    }

    pub fn symbolIsNamed(self: Language, id: u16) bool {
        return if (self.symbolInfo(id)) |info| info.metadata.named else false;
    }

    pub fn symbolIsVisible(self: Language, id: u16) bool {
        return if (self.symbolInfo(id)) |info| info.metadata.visible else true;
    }

    pub fn symbolIsExtra(self: Language, id: u16) bool {
        if (self.symbolInfo(id)) |info| {
            if (info.metadata.extra) return true;
        }
        for (self.extra_symbols) |e| {
            if (e == id) return true;
        }
        return false;
    }

    pub fn symbolIsSupertype(self: Language, id: u16) bool {
        if (self.symbolInfo(id)) |info| {
            if (info.metadata.supertype) return true;
        }
        for (self.supertypes) |s| {
            if (s == id) return true;
        }
        return false;
    }

    pub fn symbolForName(self: Language, name: []const u8, is_named: bool) ?u16 {
        for (self.symbols) |s| {
            if (std.mem.eql(u8, s.name, name) and s.metadata.named == is_named) return s.id;
        }
        for (self.symbols) |s| {
            if (std.mem.eql(u8, s.name, name)) return s.id;
        }
        return null;
    }

    pub fn fieldIdForName(self: Language, name: []const u8) ?u16 {
        return self.fields.fieldIdForName(name);
    }

    pub fn fieldNameForId(self: Language, field_id: u16) ?[]const u8 {
        return self.fields.fieldName(field_id);
    }

    pub fn nextState(self: Language, state: u16, symbol: u16) u16 {
        return self.table.gotoState(state, symbol) orelse 0;
    }

    pub fn isExtra(self: Language, symbol: u16) bool {
        return self.symbolIsExtra(symbol);
    }

    /// Alias substitution: returns the rename applied to the child at
    /// `child_index` of `production_id`, or null when the child keeps
    /// its own symbol. Applied by the parser when a rule is reduced.
    pub fn aliasFor(self: Language, production_id: u16, child_index: usize) ?aliases_mod.Alias {
        return self.aliases.aliasFor(production_id, child_index);
    }

    /// Subtype expansion: returns the subtype symbols covered by a
    /// supertype symbol, or an empty slice when the symbol has no
    /// registered subtypes.
    pub fn subtypesOf(self: Language, supertype: u16) []const u16 {
        for (self.supertype_map) |entry| {
            if (entry.supertype == supertype) return entry.subtypes;
        }
        return &.{};
    }
};

/// One supertype-to-subtypes mapping entry.
pub const SupertypeEntry = struct {
    supertype: u16,
    subtypes: []const u16 = &.{},
};

// Bundled grammars
//
// The runtime is language-independent: it consumes table data supplied by
// the host. Small grammars ship with the library for tests, examples,
// benchmarks, and documentation. The expression and s-expression tables
// live here; JSON and the outline demo live in their own modules so each
// grammar stays navigable. Re-exported below so examples and downstream
// users share the exact same tables the test-suite exercises.

pub const json_grammar = @import("json.zig");
pub const json_language: Language = json_grammar.json_language;
pub const outline_grammar = @import("outline.zig");
pub const outline_language: Language = outline_grammar.outline_language;
pub const outline_scanner = @import("outline_scanner.zig");

fn matchIdentifier(source: []const u8, start: usize) ?usize {
    if (start >= source.len) return null;
    const first = source[start];
    if (!std.ascii.isAlphabetic(first) and first != '_') return null;
    var i = start + 1;
    while (i < source.len and (std.ascii.isAlphanumeric(source[i]) or source[i] == '_')) : (i += 1) {}
    return i - start;
}

fn matchNumber(source: []const u8, start: usize) ?usize {
    if (start >= source.len) return null;
    if (!std.ascii.isDigit(source[start])) return null;
    var i = start + 1;
    while (i < source.len and std.ascii.isDigit(source[i])) : (i += 1) {}
    return i - start;
}

pub fn matchChar(comptime c: u8) TokenMatchFn {
    return struct {
        fn match(source: []const u8, start: usize) ?usize {
            if (start < source.len and source[start] == c) return 1;
            return null;
        }
    }.match;
}

pub fn matchWhitespace(source: []const u8, start: usize) ?usize {
    if (start >= source.len) return null;
    if (!std.ascii.isWhitespace(source[start])) return null;
    var i = start + 1;
    while (i < source.len and std.ascii.isWhitespace(source[i])) : (i += 1) {}
    return i - start;
}

pub const expr_sym_end: u16 = 0;
pub const expr_sym_identifier: u16 = 1;
pub const expr_sym_number: u16 = 2;
pub const expr_sym_plus: u16 = 3;
pub const expr_sym_minus: u16 = 4;
pub const expr_sym_star: u16 = 5;
pub const expr_sym_slash: u16 = 6;
pub const expr_sym_lparen: u16 = 7;
pub const expr_sym_rparen: u16 = 8;
pub const expr_sym_whitespace: u16 = 9;
pub const expr_sym_program: u16 = 10;
pub const expr_sym_expr: u16 = 11;
pub const expr_sym_term: u16 = 12;
pub const expr_sym_factor: u16 = 13;
pub const expr_sym_error: u16 = 14;

const expr_symbol_table: []const symbols_mod.SymbolInfo = &.{
    .{ .id = expr_sym_end, .name = "end", .kind = .end, .metadata = .{ .visible = false, .named = false } },
    .{ .id = expr_sym_identifier, .name = "identifier", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = expr_sym_number, .name = "number", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = expr_sym_plus, .name = "+", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = expr_sym_minus, .name = "-", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = expr_sym_star, .name = "*", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = expr_sym_slash, .name = "/", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = expr_sym_lparen, .name = "(", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = expr_sym_rparen, .name = ")", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = expr_sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = false, .named = false, .extra = true } },
    .{ .id = expr_sym_program, .name = "program", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = expr_sym_expr, .name = "expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = expr_sym_term, .name = "term", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = expr_sym_factor, .name = "factor", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = expr_sym_error, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const expr_token_matchers: []const TokenMatcher = &.{
    .{ .symbol = expr_sym_identifier, .match = matchIdentifier },
    .{ .symbol = expr_sym_number, .match = matchNumber },
    .{ .symbol = expr_sym_plus, .match = matchChar('+') },
    .{ .symbol = expr_sym_minus, .match = matchChar('-') },
    .{ .symbol = expr_sym_star, .match = matchChar('*') },
    .{ .symbol = expr_sym_slash, .match = matchChar('/') },
    .{ .symbol = expr_sym_lparen, .match = matchChar('(') },
    .{ .symbol = expr_sym_rparen, .match = matchChar(')') },
    .{ .symbol = expr_sym_whitespace, .match = matchWhitespace },
};

const expr_extra_symbols: []const u16 = &.{expr_sym_whitespace};

const expr_s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_identifier, .action = .{ .shift = 6 } },
    .{ .symbol = expr_sym_number, .action = .{ .shift = 5 } },
    .{ .symbol = expr_sym_lparen, .action = .{ .shift = 7 } },
};
const expr_s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = expr_sym_program, .state = 1 },
    .{ .symbol = expr_sym_expr, .state = 2 },
    .{ .symbol = expr_sym_term, .state = 3 },
    .{ .symbol = expr_sym_factor, .state = 4 },
};
const expr_s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_end, .action = .accept },
};
const expr_s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_plus, .action = .{ .shift = 8 } },
    .{ .symbol = expr_sym_minus, .action = .{ .shift = 9 } },
    .{ .symbol = expr_sym_end, .action = .{ .reduce = .{ .symbol = expr_sym_program, .child_count = 1, .production_id = 1 } } },
};
const expr_s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_star, .action = .{ .shift = 10 } },
    .{ .symbol = expr_sym_slash, .action = .{ .shift = 11 } },
    .{ .symbol = expr_sym_plus, .action = .{ .reduce = .{ .symbol = expr_sym_expr, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = expr_sym_minus, .action = .{ .reduce = .{ .symbol = expr_sym_expr, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = expr_sym_end, .action = .{ .reduce = .{ .symbol = expr_sym_expr, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = expr_sym_rparen, .action = .{ .reduce = .{ .symbol = expr_sym_expr, .child_count = 1, .production_id = 4 } } },
};
const expr_s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_plus, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = expr_sym_minus, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = expr_sym_star, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = expr_sym_slash, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = expr_sym_end, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = expr_sym_rparen, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 1, .production_id = 7 } } },
};
const expr_s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_plus, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = expr_sym_minus, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = expr_sym_star, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = expr_sym_slash, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = expr_sym_end, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = expr_sym_rparen, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 1, .production_id = 8 } } },
};
const expr_s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_plus, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = expr_sym_minus, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = expr_sym_star, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = expr_sym_slash, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = expr_sym_end, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = expr_sym_rparen, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 1, .production_id = 9 } } },
};
const expr_s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_identifier, .action = .{ .shift = 6 } },
    .{ .symbol = expr_sym_number, .action = .{ .shift = 5 } },
    .{ .symbol = expr_sym_lparen, .action = .{ .shift = 7 } },
};
const expr_s7_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = expr_sym_expr, .state = 12 },
    .{ .symbol = expr_sym_term, .state = 3 },
    .{ .symbol = expr_sym_factor, .state = 4 },
};
const expr_s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_identifier, .action = .{ .shift = 6 } },
    .{ .symbol = expr_sym_number, .action = .{ .shift = 5 } },
    .{ .symbol = expr_sym_lparen, .action = .{ .shift = 7 } },
};
const expr_s8_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = expr_sym_term, .state = 13 },
    .{ .symbol = expr_sym_factor, .state = 4 },
};
const expr_s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_star, .action = .{ .shift = 10 } },
    .{ .symbol = expr_sym_slash, .action = .{ .shift = 11 } },
    .{ .symbol = expr_sym_plus, .action = .{ .reduce = .{ .symbol = expr_sym_expr, .child_count = 3, .production_id = 3 } } },
    .{ .symbol = expr_sym_minus, .action = .{ .reduce = .{ .symbol = expr_sym_expr, .child_count = 3, .production_id = 3 } } },
    .{ .symbol = expr_sym_end, .action = .{ .reduce = .{ .symbol = expr_sym_expr, .child_count = 3, .production_id = 3 } } },
    .{ .symbol = expr_sym_rparen, .action = .{ .reduce = .{ .symbol = expr_sym_expr, .child_count = 3, .production_id = 3 } } },
};
const expr_s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_plus, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 3, .production_id = 5 } } },
    .{ .symbol = expr_sym_minus, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 3, .production_id = 5 } } },
    .{ .symbol = expr_sym_star, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 3, .production_id = 5 } } },
    .{ .symbol = expr_sym_slash, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 3, .production_id = 5 } } },
    .{ .symbol = expr_sym_end, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 3, .production_id = 5 } } },
    .{ .symbol = expr_sym_rparen, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 3, .production_id = 5 } } },
};
const expr_s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_plus, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 3, .production_id = 6 } } },
    .{ .symbol = expr_sym_minus, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 3, .production_id = 6 } } },
    .{ .symbol = expr_sym_star, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 3, .production_id = 6 } } },
    .{ .symbol = expr_sym_slash, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 3, .production_id = 6 } } },
    .{ .symbol = expr_sym_end, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 3, .production_id = 6 } } },
    .{ .symbol = expr_sym_rparen, .action = .{ .reduce = .{ .symbol = expr_sym_term, .child_count = 3, .production_id = 6 } } },
};
const expr_s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_plus, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 3, .production_id = 10 } } },
    .{ .symbol = expr_sym_minus, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 3, .production_id = 10 } } },
    .{ .symbol = expr_sym_star, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 3, .production_id = 10 } } },
    .{ .symbol = expr_sym_slash, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 3, .production_id = 10 } } },
    .{ .symbol = expr_sym_end, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 3, .production_id = 10 } } },
    .{ .symbol = expr_sym_rparen, .action = .{ .reduce = .{ .symbol = expr_sym_factor, .child_count = 3, .production_id = 10 } } },
};
const expr_s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_rparen, .action = .{ .shift = 17 } },
    .{ .symbol = expr_sym_plus, .action = .{ .shift = 8 } },
    .{ .symbol = expr_sym_minus, .action = .{ .shift = 9 } },
};
const expr_s9_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = expr_sym_term, .state = 14 },
    .{ .symbol = expr_sym_factor, .state = 4 },
};
const expr_s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = expr_sym_star, .action = .{ .shift = 10 } },
    .{ .symbol = expr_sym_slash, .action = .{ .shift = 11 } },
    .{ .symbol = expr_sym_plus, .action = .{ .reduce = .{ .symbol = expr_sym_expr, .child_count = 3, .production_id = 2 } } },
    .{ .symbol = expr_sym_minus, .action = .{ .reduce = .{ .symbol = expr_sym_expr, .child_count = 3, .production_id = 2 } } },
    .{ .symbol = expr_sym_end, .action = .{ .reduce = .{ .symbol = expr_sym_expr, .child_count = 3, .production_id = 2 } } },
    .{ .symbol = expr_sym_rparen, .action = .{ .reduce = .{ .symbol = expr_sym_expr, .child_count = 3, .production_id = 2 } } },
};

const expr_parse_states: []const tables_mod.ParseState = &.{
    .{ .actions = expr_s0_actions, .gotos = expr_s0_gotos },
    .{ .actions = expr_s1_actions },
    .{ .actions = expr_s2_actions },
    .{ .actions = expr_s3_actions },
    .{ .actions = expr_s4_actions },
    .{ .actions = expr_s5_actions },
    .{ .actions = expr_s6_actions },
    .{ .actions = expr_s7_actions, .gotos = expr_s7_gotos },
    .{ .actions = expr_s8_actions, .gotos = expr_s8_gotos },
    .{ .actions = expr_s8_actions, .gotos = expr_s9_gotos },
    .{ .actions = expr_s8_actions, .gotos = &.{.{ .symbol = expr_sym_factor, .state = 15 }} },
    .{ .actions = expr_s8_actions, .gotos = &.{.{ .symbol = expr_sym_factor, .state = 16 }} },
    .{ .actions = expr_s12_actions },
    .{ .actions = expr_s13_actions },
    .{ .actions = expr_s14_actions },
    .{ .actions = expr_s15_actions },
    .{ .actions = expr_s16_actions },
    .{ .actions = expr_s17_actions },
};

const expr_field_names: []const []const u8 = &.{ "left", "right" };
const expr_field_productions: []const fields_mod.FieldProduction = &.{
    .{ .production_id = 2, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 3, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 5, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 6, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
};

/// Bundled arithmetic expression language: identifiers, numbers, the
/// four binary operators with `*`/`/` binding tighter than `+`/`-`,
/// and parenthesized factors. `left`/`right` fields are bound on every
/// binary production. Used by tests, examples, and benchmarks.
pub const expression_language: Language = .{
    .metadata = .{
        .name = "expression",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.1",
        .symbol_count = 15,
        .state_count = 18,
        .field_count = 2,
    },
    .symbols = expr_symbol_table,
    .token_matchers = expr_token_matchers,
    .extra_symbols = expr_extra_symbols,
    .table = .{
        .states = expr_parse_states,
        .start_state = 0,
        .end_symbol = expr_sym_end,
        .error_symbol = expr_sym_error,
    },
    .fields = .{
        .names = expr_field_names,
        .productions = expr_field_productions,
    },
};

//
// program     := items
// items       := expression | items expression
// expression  := atom | "(" items ")" | "(" ")"
// atom        := identifier | number
//
// The parenthesized production aliases its middle child to `sequence`,
// so queries can distinguish a bare item list from a grouped list.

pub const sexp_sym_end: u16 = 0;
pub const sexp_sym_identifier: u16 = 1;
pub const sexp_sym_number: u16 = 2;
pub const sexp_sym_lparen: u16 = 3;
pub const sexp_sym_rparen: u16 = 4;
pub const sexp_sym_whitespace: u16 = 5;
pub const sexp_sym_program: u16 = 6;
pub const sexp_sym_items: u16 = 7;
pub const sexp_sym_expression: u16 = 8;
pub const sexp_sym_atom: u16 = 9;
pub const sexp_sym_error: u16 = 10;
pub const sexp_sym_sequence: u16 = 11;

const sexp_symbol_table: []const symbols_mod.SymbolInfo = &.{
    .{ .id = sexp_sym_end, .name = "end", .kind = .end, .metadata = .{ .visible = false, .named = false } },
    .{ .id = sexp_sym_identifier, .name = "identifier", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sexp_sym_number, .name = "number", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sexp_sym_lparen, .name = "(", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sexp_sym_rparen, .name = ")", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sexp_sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = false, .named = false, .extra = true } },
    .{ .id = sexp_sym_program, .name = "program", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sexp_sym_items, .name = "items", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sexp_sym_expression, .name = "expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sexp_sym_atom, .name = "atom", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sexp_sym_error, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sexp_sym_sequence, .name = "sequence", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const sexp_token_matchers: []const TokenMatcher = &.{
    .{ .symbol = sexp_sym_identifier, .match = matchIdentifier },
    .{ .symbol = sexp_sym_number, .match = matchNumber },
    .{ .symbol = sexp_sym_lparen, .match = matchChar('(') },
    .{ .symbol = sexp_sym_rparen, .match = matchChar(')') },
    .{ .symbol = sexp_sym_whitespace, .match = matchWhitespace },
};

const sexp_extra_symbols: []const u16 = &.{sexp_sym_whitespace};

const sexp_s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sexp_sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sexp_sym_number, .action = .{ .shift = 9 } },
    .{ .symbol = sexp_sym_lparen, .action = .{ .shift = 6 } },
};
const sexp_s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sexp_sym_program, .state = 1 },
    .{ .symbol = sexp_sym_items, .state = 2 },
    .{ .symbol = sexp_sym_expression, .state = 3 },
    .{ .symbol = sexp_sym_atom, .state = 4 },
};
const sexp_s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sexp_sym_end, .action = .accept },
};
const sexp_s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sexp_sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sexp_sym_number, .action = .{ .shift = 9 } },
    .{ .symbol = sexp_sym_lparen, .action = .{ .shift = 6 } },
    .{ .symbol = sexp_sym_end, .action = .{ .reduce = .{ .symbol = sexp_sym_program, .child_count = 1, .production_id = 1 } } },
};
const sexp_s2_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sexp_sym_expression, .state = 5 },
    .{ .symbol = sexp_sym_atom, .state = 4 },
};
const sexp_s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sexp_sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sexp_sym_number, .action = .{ .shift = 9 } },
    .{ .symbol = sexp_sym_lparen, .action = .{ .shift = 6 } },
    .{ .symbol = sexp_sym_rparen, .action = .{ .shift = 11 } },
};
const sexp_s6_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sexp_sym_items, .state = 7 },
    .{ .symbol = sexp_sym_expression, .state = 3 },
    .{ .symbol = sexp_sym_atom, .state = 4 },
};
const sexp_s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sexp_sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sexp_sym_number, .action = .{ .shift = 9 } },
    .{ .symbol = sexp_sym_lparen, .action = .{ .shift = 6 } },
    .{ .symbol = sexp_sym_rparen, .action = .{ .shift = 10 } },
};
const sexp_s7_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sexp_sym_expression, .state = 5 },
    .{ .symbol = sexp_sym_atom, .state = 4 },
};

const sexp_reduce_items_1: tables_mod.Action = .{ .reduce = .{ .symbol = sexp_sym_items, .child_count = 1, .production_id = 2 } };
const sexp_reduce_items_2: tables_mod.Action = .{ .reduce = .{ .symbol = sexp_sym_items, .child_count = 2, .production_id = 3 } };
const sexp_reduce_expr_atom: tables_mod.Action = .{ .reduce = .{ .symbol = sexp_sym_expression, .child_count = 1, .production_id = 4 } };
const sexp_reduce_expr_list: tables_mod.Action = .{ .reduce = .{ .symbol = sexp_sym_expression, .child_count = 3, .production_id = 5 } };
const sexp_reduce_expr_empty: tables_mod.Action = .{ .reduce = .{ .symbol = sexp_sym_expression, .child_count = 2, .production_id = 8 } };
const sexp_reduce_atom_num: tables_mod.Action = .{ .reduce = .{ .symbol = sexp_sym_atom, .child_count = 1, .production_id = 6 } };
const sexp_reduce_atom_id: tables_mod.Action = .{ .reduce = .{ .symbol = sexp_sym_atom, .child_count = 1, .production_id = 7 } };

const sexp_s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sexp_sym_identifier, .action = sexp_reduce_items_1 },
    .{ .symbol = sexp_sym_number, .action = sexp_reduce_items_1 },
    .{ .symbol = sexp_sym_lparen, .action = sexp_reduce_items_1 },
    .{ .symbol = sexp_sym_end, .action = sexp_reduce_items_1 },
    .{ .symbol = sexp_sym_rparen, .action = sexp_reduce_items_1 },
};
const sexp_s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sexp_sym_identifier, .action = sexp_reduce_expr_atom },
    .{ .symbol = sexp_sym_number, .action = sexp_reduce_expr_atom },
    .{ .symbol = sexp_sym_lparen, .action = sexp_reduce_expr_atom },
    .{ .symbol = sexp_sym_end, .action = sexp_reduce_expr_atom },
    .{ .symbol = sexp_sym_rparen, .action = sexp_reduce_expr_atom },
};
const sexp_s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sexp_sym_identifier, .action = sexp_reduce_items_2 },
    .{ .symbol = sexp_sym_number, .action = sexp_reduce_items_2 },
    .{ .symbol = sexp_sym_lparen, .action = sexp_reduce_items_2 },
    .{ .symbol = sexp_sym_end, .action = sexp_reduce_items_2 },
    .{ .symbol = sexp_sym_rparen, .action = sexp_reduce_items_2 },
};
const sexp_s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sexp_sym_identifier, .action = sexp_reduce_atom_id },
    .{ .symbol = sexp_sym_number, .action = sexp_reduce_atom_id },
    .{ .symbol = sexp_sym_lparen, .action = sexp_reduce_atom_id },
    .{ .symbol = sexp_sym_end, .action = sexp_reduce_atom_id },
    .{ .symbol = sexp_sym_rparen, .action = sexp_reduce_atom_id },
};
const sexp_s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sexp_sym_identifier, .action = sexp_reduce_atom_num },
    .{ .symbol = sexp_sym_number, .action = sexp_reduce_atom_num },
    .{ .symbol = sexp_sym_lparen, .action = sexp_reduce_atom_num },
    .{ .symbol = sexp_sym_end, .action = sexp_reduce_atom_num },
    .{ .symbol = sexp_sym_rparen, .action = sexp_reduce_atom_num },
};
const sexp_s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sexp_sym_identifier, .action = sexp_reduce_expr_list },
    .{ .symbol = sexp_sym_number, .action = sexp_reduce_expr_list },
    .{ .symbol = sexp_sym_lparen, .action = sexp_reduce_expr_list },
    .{ .symbol = sexp_sym_end, .action = sexp_reduce_expr_list },
    .{ .symbol = sexp_sym_rparen, .action = sexp_reduce_expr_list },
};
const sexp_s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sexp_sym_identifier, .action = sexp_reduce_expr_empty },
    .{ .symbol = sexp_sym_number, .action = sexp_reduce_expr_empty },
    .{ .symbol = sexp_sym_lparen, .action = sexp_reduce_expr_empty },
    .{ .symbol = sexp_sym_end, .action = sexp_reduce_expr_empty },
    .{ .symbol = sexp_sym_rparen, .action = sexp_reduce_expr_empty },
};

const sexp_parse_states: []const tables_mod.ParseState = &.{
    .{ .actions = sexp_s0_actions, .gotos = sexp_s0_gotos },
    .{ .actions = sexp_s1_actions },
    .{ .actions = sexp_s2_actions, .gotos = sexp_s2_gotos },
    .{ .actions = sexp_s3_actions },
    .{ .actions = sexp_s4_actions },
    .{ .actions = sexp_s5_actions },
    .{ .actions = sexp_s6_actions, .gotos = sexp_s6_gotos },
    .{ .actions = sexp_s7_actions, .gotos = sexp_s7_gotos },
    .{ .actions = sexp_s8_actions },
    .{ .actions = sexp_s9_actions },
    .{ .actions = sexp_s10_actions },
    .{ .actions = sexp_s11_actions },
};

const sexp_alias_sequences: []const aliases_mod.AliasSequence = &.{
    .{
        .production_id = 5,
        .child_index = 1,
        .alias = .{ .symbol = sexp_sym_items, .value = sexp_sym_sequence, .is_named = true },
    },
};

/// Bundled s-expression language: nested parenthesized lists of
/// identifiers and numbers, e.g. `(add 1 (mul 2 3))`. The grouped-list
/// production aliases its middle child to `sequence`, demonstrating
/// alias substitution end to end.
pub const sexp_language: Language = .{
    .metadata = .{
        .name = "sexp",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.1",
        .symbol_count = 12,
        .state_count = 12,
        .field_count = 0,
    },
    .symbols = sexp_symbol_table,
    .token_matchers = sexp_token_matchers,
    .extra_symbols = sexp_extra_symbols,
    .table = .{
        .states = sexp_parse_states,
        .start_state = 0,
        .end_symbol = sexp_sym_end,
        .error_symbol = sexp_sym_error,
    },
    .aliases = .{ .sequences = sexp_alias_sequences },
};

test "language: expression metadata validates" {
    try expression_language.validate();
    try std.testing.expectEqualStrings("expression", expression_language.metadata.name);
    try std.testing.expectEqual(@as(usize, 15), expression_language.symbolCount());
    try std.testing.expectEqual(@as(usize, 18), expression_language.table.stateCount());
}

test "language: symbol and field lookup" {
    try std.testing.expectEqual(@as(?u16, 1), expression_language.symbolForName("identifier", true));
    try std.testing.expectEqual(@as(?u16, 3), expression_language.symbolForName("+", false));
    try std.testing.expect(expression_language.symbolIsExtra(expr_sym_whitespace));
    try std.testing.expect(!expression_language.symbolIsExtra(expr_sym_plus));
    try std.testing.expectEqual(@as(?u16, 1), expression_language.fieldIdForName("left"));
    try std.testing.expectEqual(@as(?u16, 2), expression_language.fieldIdForName("right"));
    try std.testing.expectEqualStrings("left", expression_language.fieldNameForId(1).?);
    try std.testing.expect(expression_language.fieldIdForName("nope") == null);
}

test "language: incompatible ABI rejected" {
    var bad = expression_language;
    bad.metadata.abi_version = metadata_mod.abi_version_min - 1;
    try std.testing.expectError(error.IncompatibleAbiVersion, bad.validate());
}

test "language: sexp alias substitution registered" {
    const alias = sexp_language.aliasFor(5, 1);
    try std.testing.expect(alias != null);
    try std.testing.expectEqual(sexp_sym_sequence, alias.?.value);
    try std.testing.expect(alias.?.is_named);
    try std.testing.expect(sexp_language.aliasFor(5, 0) == null);
    try std.testing.expect(sexp_language.aliasFor(2, 0) == null);
    try std.testing.expectEqualStrings("sequence", sexp_language.symbolName(sexp_sym_sequence));
}

test "language: subtype map defaults to empty" {
    try std.testing.expectEqual(@as(usize, 0), expression_language.subtypesOf(expr_sym_expr).len);
    try std.testing.expect(!expression_language.symbolIsSupertype(expr_sym_expr));
}
