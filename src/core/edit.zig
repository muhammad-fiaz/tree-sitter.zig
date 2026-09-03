const std = @import("std");
const point_mod = @import("point.zig");

pub const Point = point_mod.Point;

pub const InputEdit = struct {
    start_byte: u32 = 0,
    old_end_byte: u32 = 0,
    new_end_byte: u32 = 0,
    start_point: Point = .{},
    old_end_point: Point = .{},
    new_end_point: Point = .{},

    pub fn isInsertion(self: InputEdit) bool {
        return self.old_end_byte == self.start_byte;
    }

    pub fn isDeletion(self: InputEdit) bool {
        return self.new_end_byte == self.start_byte;
    }

    pub fn oldLength(self: InputEdit) u32 {
        return self.old_end_byte - self.start_byte;
    }

    pub fn newLength(self: InputEdit) u32 {
        return self.new_end_byte - self.start_byte;
    }

    pub fn editedByteCount(self: InputEdit) i64 {
        return @as(i64, @intCast(self.new_end_byte)) - @as(i64, @intCast(self.old_end_byte));
    }

    pub fn translateByte(self: InputEdit, byte: u32) u32 {
        if (byte < self.start_byte) return byte;
        if (byte >= self.old_end_byte) {
            const delta = self.editedByteCount();
            return @as(u32, @intCast(@as(i64, @intCast(byte)) + delta));
        }
        const offset = @min(byte - self.start_byte, self.newLength());
        return self.start_byte + offset;
    }

    pub fn translatePoint(self: InputEdit, point: Point) Point {
        if (point.lessThan(self.start_point)) return point;
        if (point.lessOrEql(self.old_end_point)) {
            if (self.old_end_point.row == self.start_point.row) {
                const clamped_col = @min(point.column, self.old_end_point.column);
                const offset = clamped_col -| self.start_point.column;
                return .{
                    .row = self.new_end_point.row,
                    .column = self.new_end_point.column +| offset,
                };
            }
            if (point.row == self.old_end_point.row) {
                return .{
                    .row = self.new_end_point.row,
                    .column = self.new_end_point.column +| (point.column -| self.old_end_point.column),
                };
            }
            return .{ .row = self.new_end_point.row, .column = point.column };
        }
        const row_delta = @as(i64, @intCast(self.new_end_point.row)) - @as(i64, @intCast(self.old_end_point.row));
        const new_row = @as(u32, @intCast(@as(i64, @intCast(point.row)) + row_delta));
        if (point.row == self.old_end_point.row) {
            const col_delta = @as(i64, @intCast(self.new_end_point.column)) - @as(i64, @intCast(self.old_end_point.column));
            return .{ .row = new_row, .column = @as(u32, @intCast(@as(i64, @intCast(point.column)) + col_delta)) };
        }
        return .{ .row = new_row, .column = point.column };
    }
};

test "edit: byte translation" {
    const e = InputEdit{
        .start_byte = 2,
        .old_end_byte = 4,
        .new_end_byte = 7,
        .start_point = .{ .row = 0, .column = 2 },
        .old_end_point = .{ .row = 0, .column = 4 },
        .new_end_point = .{ .row = 0, .column = 7 },
    };
    try std.testing.expectEqual(@as(u32, 1), e.translateByte(1));
    try std.testing.expectEqual(@as(u32, 8), e.translateByte(5));
    try std.testing.expect(!e.isInsertion());
    try std.testing.expectEqual(@as(i64, 3), e.editedByteCount());
}
