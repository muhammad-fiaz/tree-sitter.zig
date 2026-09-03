const std = @import("std");

pub const Point = struct {
    row: u32 = 0,
    column: u32 = 0,

    pub fn eql(a: Point, b: Point) bool {
        return a.row == b.row and a.column == b.column;
    }

    pub fn order(a: Point, b: Point) std.math.Order {
        if (a.row != b.row) return std.math.order(a.row, b.row);
        return std.math.order(a.column, b.column);
    }

    pub fn lessThan(a: Point, b: Point) bool {
        return a.order(b) == .lt;
    }

    pub fn lessOrEql(a: Point, b: Point) bool {
        const o = a.order(b);
        return o == .lt or o == .eq;
    }

    pub fn add(a: Point, b: Point) Point {
        if (b.row == 0) return .{ .row = a.row, .column = a.column + b.column };
        return .{ .row = a.row + b.row, .column = b.column };
    }

    pub fn sub(a: Point, b: Point) Point {
        std.debug.assert(b.lessOrEql(a));
        if (a.row == b.row) return .{ .row = 0, .column = a.column - b.column };
        return .{ .row = a.row - b.row, .column = a.column };
    }
};

pub fn advancePoint(point: Point, byte: u8) Point {
    if (byte == '\n') return .{ .row = point.row + 1, .column = 0 };
    return .{ .row = point.row, .column = point.column + 1 };
}

pub fn pointForBytes(source: []const u8, byte_offset: usize) Point {
    std.debug.assert(byte_offset <= source.len);
    var point = Point{};
    for (source[0..byte_offset]) |b| point = advancePoint(point, b);
    return point;
}

test "point: advance and lookup" {
    const p = advancePoint(.{}, 'a');
    try std.testing.expectEqual(Point{ .row = 0, .column = 1 }, p);
    const n = advancePoint(p, '\n');
    try std.testing.expectEqual(Point{ .row = 1, .column = 0 }, n);
    try std.testing.expectEqual(Point{ .row = 1, .column = 1 }, pointForBytes("a\nb", 3));
    try std.testing.expect((Point{ .row = 0, .column = 1 }).lessThan(.{ .row = 1, .column = 0 }));
}
