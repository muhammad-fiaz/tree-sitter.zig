const std = @import("std");
const core = @import("../core/core.zig");
const language_mod = @import("../language/language.zig");
const lexer_mod = @import("../lexer/lexer.zig");
const lookahead_mod = @import("lookahead.zig");
const stack_mod = @import("stack.zig");

pub const ParseState = struct {
    language: language_mod.Language,
    source: []const u8 = &.{},
    tokenizer: lookahead_mod.Tokenizer,
    stack: stack_mod.Stack = .{},
    lookahead: lexer_mod.Token = .{},
    has_lookahead: bool = false,
    error_cost: u32 = 0,
    recovery_ops: u32 = 0,
    missing_inserts: u32 = 0,
    error_span_open: bool = false,
    error_start_byte: u32 = 0,
    error_start_point: core.Point = .{},
    pending_errors: std.ArrayList(u32) = .empty,
    start_symbol: u16 = 0,

    pub fn init(language: language_mod.Language) ParseState {
        return .{
            .language = language,
            .tokenizer = lookahead_mod.Tokenizer.init(language),
        };
    }

    pub fn deinit(self: *ParseState, gpa: std.mem.Allocator) void {
        self.stack.deinit(gpa);
        self.pending_errors.deinit(gpa);
        self.* = undefined;
    }

    pub fn reset(self: *ParseState, gpa: std.mem.Allocator, source: []const u8) std.mem.Allocator.Error!void {
        self.source = source;
        self.tokenizer.reset(source);
        self.stack.clearRetainingCapacity();
        try self.stack.initWithState(gpa, self.language.table.start_state);
        self.pending_errors.clearRetainingCapacity();
        self.has_lookahead = false;
        self.error_cost = 0;
        self.recovery_ops = 0;
        self.missing_inserts = 0;
        self.error_span_open = false;
        self.start_symbol = detectStartSymbol(self.language);
    }

    pub fn currentState(self: *const ParseState) u16 {
        return self.stack.top();
    }

    pub fn ensureLookahead(self: *ParseState) void {
        if (!self.has_lookahead) {
            self.lookahead = self.tokenizer.nextToken();
            self.has_lookahead = true;
        }
    }

    pub fn consumeLookahead(self: *ParseState) void {
        self.has_lookahead = false;
    }
};

pub fn detectStartSymbol(language: language_mod.Language) u16 {
    const table = language.table;
    if (table.start_state >= table.states.len) return 0;
    for (table.states[table.start_state].gotos) |g| {
        if (g.state < table.states.len) {
            for (table.states[g.state].actions) |a| {
                if (a.symbol == table.end_symbol and a.action == .accept) return g.symbol;
            }
        }
    }
    return 0;
}
