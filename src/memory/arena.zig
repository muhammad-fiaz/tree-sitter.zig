const std = @import("std");

pub const Arena = struct {
    inner: std.heap.ArenaAllocator,
    owner: std.mem.Allocator,

    pub fn init(owner: std.mem.Allocator) Arena {
        return .{ .inner = std.heap.ArenaAllocator.init(owner), .owner = owner };
    }

    pub fn deinit(self: *Arena) void {
        self.inner.deinit();
    }

    pub fn allocator(self: *Arena) std.mem.Allocator {
        return self.inner.allocator();
    }

    pub fn reset(self: *Arena) void {
        _ = self.inner.reset(.retain_capacity);
    }

    pub fn queryCapacity(self: Arena) usize {
        return self.inner.queryCapacity();
    }
};

test "ownership: arena reset reuses memory" {
    var arena = Arena.init(std.testing.allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
    const a = try gpa.alloc(u8, 64);
    @memset(a, 0xAB);
    try std.testing.expect(arena.queryCapacity() >= 64);
    arena.reset();
    const b = try gpa.alloc(u8, 64);
    @memset(b, 0xCD);
    try std.testing.expectEqual(@as(u8, 0xCD), b[0]);
}
