const std = @import("std");
const tables_mod = @import("../language/tables.zig");

pub const ActionKind = enum {
    none,
    shift,
    reduce,
    accept,
    recover,
};

pub fn kindOf(action: tables_mod.Action) ActionKind {
    return switch (action) {
        .none => .none,
        .shift => .shift,
        .reduce => .reduce,
        .accept => .accept,
        .recover => .recover,
    };
}

pub fn isShift(action: tables_mod.Action) bool {
    return action == .shift;
}

pub fn isReduce(action: tables_mod.Action) bool {
    return action == .reduce;
}

pub fn isAccept(action: tables_mod.Action) bool {
    return action == .accept;
}

pub fn shiftState(action: tables_mod.Action) ?u16 {
    return switch (action) {
        .shift => |s| s,
        else => null,
    };
}

pub fn reduceRule(action: tables_mod.Action) ?tables_mod.ReduceRule {
    return switch (action) {
        .reduce => |r| r,
        else => null,
    };
}
