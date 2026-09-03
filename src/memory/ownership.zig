const std = @import("std");

pub const Ownership = enum {
    owned,
    borrowed,
    shared,
};

pub const OwnerToken = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) OwnerToken {
        return .{ .allocator = allocator };
    }

    pub fn alloc(self: OwnerToken, comptime T: type, n: usize) std.mem.Allocator.Error![]T {
        return try self.allocator.alloc(T, n);
    }

    pub fn dupe(self: OwnerToken, comptime T: type, src: []const T) std.mem.Allocator.Error![]T {
        return try self.allocator.dupe(T, src);
    }

    pub fn free(self: OwnerToken, memory: anytype) void {
        self.allocator.free(memory);
    }
};
