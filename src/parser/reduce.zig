const std = @import("std");
const core = @import("../core/core.zig");
const language_mod = @import("../language/language.zig");
const tables_mod = @import("../language/tables.zig");
const lexer_mod = @import("../lexer/lexer.zig");
const subtree_mod = @import("../tree/subtree.zig");

pub const invalid_symbol: u16 = std.math.maxInt(u16);

pub fn makeTokenNode(
    language: language_mod.Language,
    token: lexer_mod.Token,
    shift_state: u16,
) subtree_mod.Subtree {
    const info = language.symbolInfo(token.symbol);
    const named = if (info) |i| i.metadata.named else false;
    const visible = if (info) |i| i.metadata.visible else true;
    return .{
        .symbol = token.symbol,
        .start_byte = token.start_byte,
        .end_byte = token.end_byte,
        .start_point = token.start_point,
        .end_point = token.end_point,
        .named = named,
        .visible = visible,
        .extra = token.extra,
        .missing = token.missing,
        .is_error = false,
        .has_error = false,
        .reuse_state = shift_state,
    };
}

pub fn makeErrorLeaf(
    error_symbol: u16,
    start_byte: u32,
    end_byte: u32,
    start_point: core.Point,
    end_point: core.Point,
) subtree_mod.Subtree {
    return .{
        .symbol = error_symbol,
        .start_byte = start_byte,
        .end_byte = end_byte,
        .start_point = start_point,
        .end_point = end_point,
        .named = true,
        .visible = true,
        .is_error = true,
        .has_error = true,
    };
}

pub fn makeMissingNode(
    language: language_mod.Language,
    symbol: u16,
    byte: u32,
    point: core.Point,
    shift_state: u16,
) subtree_mod.Subtree {
    const info = language.symbolInfo(symbol);
    const named = if (info) |i| i.metadata.named else true;
    const visible = if (info) |i| i.metadata.visible else true;
    return .{
        .symbol = symbol,
        .start_byte = byte,
        .end_byte = byte,
        .start_point = point,
        .end_point = point,
        .named = named,
        .visible = visible,
        .missing = true,
        .has_error = true,
        .reuse_state = shift_state,
    };
}

pub fn makeInteriorNode(
    language: language_mod.Language,
    pool: *subtree_mod.SubtreePool,
    symbol: u16,
    production_id: u16,
    children: []const u32,
    error_symbol: u16,
    start_state: u16,
) subtree_mod.Subtree {
    std.debug.assert(children.len > 0);
    // Alias substitution: rename children covered by the language's
    // alias map before computing counts, so `nodeType()` and query
    // matching observe the aliased name.
    if (language.aliases.hasAliases()) {
        for (children, 0..) |idx, i| {
            if (language.aliasFor(production_id, i)) |alias| {
                const child = &pool.nodes.items[idx];
                child.symbol = alias.value;
                child.named = alias.is_named;
            }
        }
    }
    const first = pool.nodes.items[children[0]];
    const last = pool.nodes.items[children[children.len - 1]];
    var named_count: u32 = 0;
    var has_error = false;
    var descendant_count: u32 = @as(u32, @intCast(children.len));
    for (children) |idx| {
        const c = pool.nodes.items[idx];
        if (c.named) named_count += 1;
        if (c.has_error or c.is_error) has_error = true;
        descendant_count += c.descendant_count;
    }
    const info = language.symbolInfo(symbol);
    const named = if (info) |i| i.metadata.named else true;
    const visible = if (info) |i| i.metadata.visible else true;
    return .{
        .symbol = symbol,
        .production_id = production_id,
        .start_byte = first.start_byte,
        .end_byte = last.end_byte,
        .start_point = first.start_point,
        .end_point = last.end_point,
        .named = named,
        .visible = visible,
        .is_error = symbol == error_symbol,
        .has_error = has_error or symbol == error_symbol,
        .named_child_count = named_count,
        .descendant_count = descendant_count,
        .reuse_state = start_state,
    };
}

pub fn reduceNodes(
    language: language_mod.Language,
    pool: *subtree_mod.SubtreePool,
    rule: tables_mod.ReduceRule,
    child_indices: []const u32,
    error_symbol: u16,
    start_state: u16,
) subtree_mod.Subtree {
    std.debug.assert(child_indices.len == rule.child_count);
    return makeInteriorNode(language, pool, rule.symbol, rule.production_id, child_indices, error_symbol, start_state);
}

pub fn makeEmptyNode(
    language: language_mod.Language,
    symbol: u16,
    byte: u32,
    point: core.Point,
) subtree_mod.Subtree {
    const info = language.symbolInfo(symbol);
    const named = if (info) |i| i.metadata.named else true;
    return .{
        .symbol = symbol,
        .start_byte = byte,
        .end_byte = byte,
        .start_point = point,
        .end_point = point,
        .named = named,
        .visible = true,
    };
}
