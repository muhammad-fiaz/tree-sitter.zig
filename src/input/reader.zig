const std = @import("std");
const core = @import("../core/core.zig");
const input_mod = @import("input.zig");

pub const ReaderSource = struct {
    reader: *std.Io.Reader,
    buffer: []u8,
    buffered_from: usize = 0,

    pub fn init(reader: *std.Io.Reader, buffer: []u8) ReaderSource {
        return .{ .reader = reader, .buffer = buffer };
    }

    fn readFn(payload: ?*anyopaque, byte_index: u32, position: core.Point, bytes_read: *u32) ?[*]const u8 {
        _ = position;
        const self: *ReaderSource = @ptrCast(@alignCast(payload orelse {
            bytes_read.* = 0;
            return null;
        }));
        const idx: usize = @as(usize, @intCast(byte_index));
        if (idx < self.buffered_from) {
            bytes_read.* = 0;
            return null;
        }
        const buffered_len = self.buffer.len;
        if (idx < self.buffered_from + buffered_len and buffered_len > 0) {
            const off = idx - self.buffered_from;
            const n = @min(buffered_len - off, std.math.maxInt(u32));
            bytes_read.* = @as(u32, @intCast(n));
            return self.buffer.ptr + off;
        }
        const n = self.reader.readSliceShort(self.buffer) catch {
            bytes_read.* = 0;
            return null;
        };
        if (n == 0) {
            bytes_read.* = 0;
            return null;
        }
        self.buffered_from = idx;
        bytes_read.* = @as(u32, @intCast(@min(n, std.math.maxInt(u32))));
        return self.buffer.ptr;
    }

    pub fn input(self: *ReaderSource) input_mod.Input {
        return .{ .payload = self, .read = readFn, .encoding = .utf8 };
    }
};

test "reader: source streams fixed buffer in windows" {
    var fixed = std.Io.Reader.fixed("1 + 2");
    var backing: [4]u8 = undefined;
    var src = ReaderSource.init(&fixed, &backing);
    const in = src.input();
    const c0 = in.chunk(0, .{}).?;
    try std.testing.expectEqual(@as(u32, 4), c0.len);
    try std.testing.expectEqualSlices(u8, "1 + ", c0.ptr[0..c0.len]);
    const c1 = in.chunk(4, .{}).?;
    try std.testing.expectEqual(@as(u32, 1), c1.len);
    try std.testing.expectEqual(@as(u8, '2'), c1.ptr[0]);
    try std.testing.expect(in.chunk(5, .{}) == null);
}
