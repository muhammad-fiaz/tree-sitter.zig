const std = @import("std");

pub const LexState = struct {
    state_id: u16 = 0,
    found_token: bool = false,

    pub fn reset(self: *LexState, state_id: u16) void {
        self.state_id = state_id;
        self.found_token = false;
    }
};

pub const LexMode = struct {
    lex_state: u16 = 0,
    external_lex_state: u16 = 0,
};

pub const LexModeStack = struct {
    modes: std.ArrayList(LexMode) = .empty,

    pub fn deinit(self: *LexModeStack, gpa: std.mem.Allocator) void {
        self.modes.deinit(gpa);
    }

    pub fn push(self: *LexModeStack, gpa: std.mem.Allocator, mode: LexMode) std.mem.Allocator.Error!void {
        try self.modes.append(gpa, mode);
    }

    pub fn pop(self: *LexModeStack) ?LexMode {
        return self.modes.pop();
    }

    pub fn current(self: *const LexModeStack) LexMode {
        if (self.modes.items.len == 0) return .{};
        return self.modes.items[self.modes.items.len - 1];
    }

    pub fn clearRetainingCapacity(self: *LexModeStack) void {
        self.modes.clearRetainingCapacity();
    }
};
