const std = @import("std");

pub const RefCount = struct {
    value: std.atomic.Value(u32),

    pub fn init(initial: u32) RefCount {
        return .{ .value = std.atomic.Value(u32).init(initial) };
    }

    pub fn acquire(self: *RefCount) u32 {
        return self.value.fetchAdd(1, .acquire) + 1;
    }

    pub fn release(self: *RefCount) u32 {
        return self.value.fetchSub(1, .release) - 1;
    }

    pub fn load(self: *const RefCount) u32 {
        return self.value.load(.acquire);
    }
};

test "ownership: refcount acquire release" {
    var rc = RefCount.init(1);
    try std.testing.expectEqual(@as(u32, 1), rc.load());
    try std.testing.expectEqual(@as(u32, 2), rc.acquire());
    try std.testing.expectEqual(@as(u32, 1), rc.release());
    try std.testing.expectEqual(@as(u32, 0), rc.release());
}
