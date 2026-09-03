const std = @import("std");
const point_mod = @import("point.zig");

pub const Point = point_mod.Point;

pub const Length = struct {
    bytes: u32 = 0,
    extent: Point = .{},

    pub fn eql(a: Length, b: Length) bool {
        return a.bytes == b.bytes and a.extent.eql(b.extent);
    }

    pub fn add(a: Length, b: Length) Length {
        return .{
            .bytes = a.bytes + b.bytes,
            .extent = a.extent.add(b.extent),
        };
    }

    pub fn sub(a: Length, b: Length) Length {
        std.debug.assert(b.bytes <= a.bytes);
        return .{
            .bytes = a.bytes - b.bytes,
            .extent = a.extent.sub(b.extent),
        };
    }

    pub fn isZero(self: Length) bool {
        return self.bytes == 0;
    }
};

pub fn lengthOfSlice(source: []const u8, start: usize, end: usize) Length {
    std.debug.assert(start <= end);
    std.debug.assert(end <= source.len);
    var extent = Point{};
    for (source[start..end]) |b| extent = point_mod.advancePoint(extent, b);
    return .{ .bytes = @as(u32, @intCast(end - start)), .extent = extent };
}

pub fn byteOffsetToPoint(source: []const u8, byte_offset: usize) Point {
    return point_mod.pointForBytes(source, byte_offset);
}

test "position: slice length" {
    const l = lengthOfSlice("ab\nc", 0, 4);
    try std.testing.expectEqual(@as(u32, 4), l.bytes);
    try std.testing.expectEqual(@as(u32, 1), l.extent.row);
    try std.testing.expectEqual(@as(u32, 1), l.extent.column);
    try std.testing.expect(byteOffsetToPoint("ab\nc", 3).eql(.{ .row = 1, .column = 0 }));
}
