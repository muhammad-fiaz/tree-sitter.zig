const std = @import("std");

pub const ReduceRule = struct {
    symbol: u16,
    child_count: u8,
    production_id: u16 = 0,
    dynamic_precedence: i32 = 0,
};

pub const Action = union(enum) {
    none,
    shift: u16,
    reduce: ReduceRule,
    accept,
    recover,

    pub fn isNone(self: Action) bool {
        return self == .none;
    }
};

pub const ActionEntry = struct {
    symbol: u16,
    action: Action,
};

pub const GotoEntry = struct {
    symbol: u16,
    state: u16,
};

pub const ParseState = struct {
    actions: []const ActionEntry = &.{},
    gotos: []const GotoEntry = &.{},
    lex_state: u16 = 0,
    is_end_state: bool = false,
};

pub const ParseTable = struct {
    states: []const ParseState = &.{},
    start_state: u16 = 0,
    end_symbol: u16 = 0,
    error_symbol: u16 = 0,
    error_repeat_symbol: u16 = 0,

    pub fn stateCount(self: ParseTable) usize {
        return self.states.len;
    }

    pub fn actionFor(self: ParseTable, state: u16, symbol: u16) Action {
        if (state >= self.states.len) return .none;
        for (self.states[state].actions) |entry| {
            if (entry.symbol == symbol) return entry.action;
        }
        return .none;
    }

    pub fn gotoState(self: ParseTable, state: u16, symbol: u16) ?u16 {
        if (state >= self.states.len) return null;
        for (self.states[state].gotos) |entry| {
            if (entry.symbol == symbol) return entry.state;
        }
        return null;
    }
};
