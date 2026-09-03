const std = @import("std");
const core = @import("../core/core.zig");
const input_mod = @import("input.zig");

pub const MemorySource = struct {
    bytes: []const u8,

    pub fn init(bytes: []const u8) MemorySource {
        return .{ .bytes = bytes };
    }

    fn readFn(payload: ?*anyopaque, byte_index: u32, position: core.Point, bytes_read: *u32) ?[*]const u8 {
        _ = position;
        const self: *const MemorySource = @ptrCast(@alignCast(payload orelse {
            bytes_read.* = 0;
            return null;
        }));
        const idx: usize = @as(usize, @intCast(byte_index));
        if (idx >= self.bytes.len) {
            bytes_read.* = 0;
            return null;
        }
        const remaining = self.bytes.len - idx;
        const n: u32 = @as(u32, @intCast(@min(remaining, std.math.maxInt(u32))));
        bytes_read.* = n;
        return self.bytes.ptr + idx;
    }

    pub fn input(self: *MemorySource) input_mod.Input {
        return .{ .payload = self, .read = readFn, .encoding = .utf8 };
    }
};

test "input: memory source chunks" {
    var mem = MemorySource.init("hello");
    const in = mem.input();
    const c0 = in.chunk(0, .{}).?;
    try std.testing.expectEqual(@as(u32, 5), c0.len);
    try std.testing.expectEqualSlices(u8, "hello", c0.ptr[0..c0.len]);
    const c2 = in.chunk(2, .{}).?;
    try std.testing.expectEqualSlices(u8, "llo", c2.ptr[0..c2.len]);
    try std.testing.expect(in.chunk(5, .{}) == null);
    try std.testing.expect(in.chunk(99, .{}) == null);
}
