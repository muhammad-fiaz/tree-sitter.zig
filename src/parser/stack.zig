const std = @import("std");

pub const StackEntry = struct {
    state: u16,
    node: u32,
};

pub const Stack = struct {
    states: std.ArrayList(u16) = .empty,
    values: std.ArrayList(u32) = .empty,

    pub fn deinit(self: *Stack, gpa: std.mem.Allocator) void {
        self.states.deinit(gpa);
        self.values.deinit(gpa);
        self.* = undefined;
    }

    pub fn clearRetainingCapacity(self: *Stack) void {
        self.states.clearRetainingCapacity();
        self.values.clearRetainingCapacity();
    }

    pub fn initWithState(self: *Stack, gpa: std.mem.Allocator, state: u16) std.mem.Allocator.Error!void {
        self.clearRetainingCapacity();
        try self.states.append(gpa, state);
    }

    pub fn depth(self: *const Stack) usize {
        return self.states.items.len;
    }

    pub fn top(self: *const Stack) u16 {
        std.debug.assert(self.states.items.len > 0);
        return self.states.items[self.states.items.len - 1];
    }

    pub fn push(self: *Stack, gpa: std.mem.Allocator, state: u16, node: u32) std.mem.Allocator.Error!void {
        try self.states.append(gpa, state);
        try self.values.append(gpa, node);
    }

    pub fn pop(self: *Stack) ?StackEntry {
        const state = self.states.pop() orelse return null;
        const node = self.values.pop() orelse {
            self.states.appendAssumeCapacity(state);
            return null;
        };
        return .{ .state = state, .node = node };
    }

    pub fn popMany(self: *Stack, n: usize) void {
        std.debug.assert(n < self.states.items.len);
        var i: usize = 0;
        while (i < n) : (i += 1) {
            _ = self.states.pop();
            _ = self.values.pop();
        }
    }

    pub fn truncateValues(self: *Stack, n: usize) void {
        std.debug.assert(n <= self.values.items.len);
        self.values.items.len = n;
    }
};

test "stack: push pop depth" {
    var stack = Stack{};
    defer stack.deinit(std.testing.allocator);
    try stack.initWithState(std.testing.allocator, 0);
    try std.testing.expectEqual(@as(usize, 1), stack.depth());
    try stack.push(std.testing.allocator, 5, 0);
    try stack.push(std.testing.allocator, 7, 1);
    try std.testing.expectEqual(@as(usize, 3), stack.depth());
    try std.testing.expectEqual(@as(u16, 7), stack.top());
    const e = stack.pop().?;
    try std.testing.expectEqual(@as(u16, 7), e.state);
    try std.testing.expectEqual(@as(u32, 1), e.node);
    try std.testing.expectEqual(@as(usize, 2), stack.depth());
}

test "stack: pop many" {
    var stack = Stack{};
    defer stack.deinit(std.testing.allocator);
    try stack.initWithState(std.testing.allocator, 0);
    try stack.push(std.testing.allocator, 1, 10);
    try stack.push(std.testing.allocator, 2, 11);
    try stack.push(std.testing.allocator, 3, 12);
    stack.popMany(3);
    try std.testing.expectEqual(@as(usize, 1), stack.depth());
    try std.testing.expectEqual(@as(u16, 0), stack.top());
}

test "stack: reset retains usability" {
    var stack = Stack{};
    defer stack.deinit(std.testing.allocator);
    try stack.initWithState(std.testing.allocator, 0);
    try stack.push(std.testing.allocator, 4, 2);
    try stack.initWithState(std.testing.allocator, 9);
    try std.testing.expectEqual(@as(usize, 1), stack.depth());
    try std.testing.expectEqual(@as(u16, 9), stack.top());
}
