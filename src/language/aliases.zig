const std = @import("std");

/// A single alias rule: within one grammar production, the child at
/// `child_index` is renamed to `value` (a symbol id present in the
/// language's symbol table) with the given named/anonymous flag.
///
/// Mirrors the upstream `AliasSequence` concept, stored sparsely so a
/// production only lists the children it actually renames.
pub const Alias = struct {
    symbol: u16,
    value: u16,
    is_named: bool,
};

pub const AliasSequence = struct {
    production_id: u16,
    child_index: u32,
    alias: Alias,
};

/// Sparse alias map: one entry per (production, child) rename.
pub const AliasMap = struct {
    sequences: []const AliasSequence = &.{},

    pub fn aliasFor(self: AliasMap, production_id: u16, child_index: usize) ?Alias {
        for (self.sequences) |seq| {
            if (seq.production_id == production_id and seq.child_index == child_index) {
                return seq.alias;
            }
        }
        return null;
    }

    pub fn hasAliases(self: AliasMap) bool {
        return self.sequences.len > 0;
    }
};
