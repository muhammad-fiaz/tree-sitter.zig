const std = @import("std");
const point_mod = @import("point.zig");

pub const Point = point_mod.Point;

pub const Range = struct {
    start_byte: u32 = 0,
    end_byte: u32 = 0,
    start_point: Point = .{},
    end_point: Point = .{},

    pub fn isEmpty(self: Range) bool {
        return self.start_byte == self.end_byte;
    }

    pub fn containsByte(self: Range, byte: u32) bool {
        return self.start_byte <= byte and byte < self.end_byte;
    }

    pub fn containsRange(self: Range, other: Range) bool {
        return self.start_byte <= other.start_byte and other.end_byte <= self.end_byte;
    }

    pub fn overlaps(self: Range, other: Range) bool {
        return self.start_byte < other.end_byte and other.start_byte < self.end_byte;
    }
};

pub fn rangeContainsPoint(range: Range, point: Point) bool {
    return range.start_point.lessOrEql(point) and point.lessOrEql(range.end_point);
}

test "range: containment" {
    const r = Range{ .start_byte = 2, .end_byte = 8, .start_point = .{}, .end_point = .{ .row = 0, .column = 8 } };
    try std.testing.expect(r.containsByte(2));
    try std.testing.expect(!r.containsByte(8));
    try std.testing.expect(!r.isEmpty());
    try std.testing.expect(r.overlaps(.{ .start_byte = 7, .end_byte = 9 }));
    try std.testing.expect(!r.overlaps(.{ .start_byte = 8, .end_byte = 9 }));
}
