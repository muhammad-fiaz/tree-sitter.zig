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

    pub fn edit(self: *Range, start_byte: u32, old_end_byte: u32, new_end_byte: u32, start_point: Point, old_end_point: Point, new_end_point: Point) void {
        if (self.end_byte >= old_end_byte) {
            if (self.end_byte != std.math.maxInt(u32)) {
                self.end_byte = new_end_byte + (self.end_byte - old_end_byte);
                self.end_point = new_end_point.add(self.end_point.sub(old_end_point));
                if (self.end_byte < new_end_byte) {
                    self.end_byte = std.math.maxInt(u32);
                    self.end_point = .{ .row = std.math.maxInt(u32), .column = std.math.maxInt(u32) };
                }
            }
        } else if (self.end_byte > start_byte) {
            self.end_byte = start_byte;
            self.end_point = start_point;
        }

        if (self.start_byte >= old_end_byte) {
            self.start_byte = new_end_byte + (self.start_byte - old_end_byte);
            self.start_point = new_end_point.add(self.start_point.sub(old_end_point));
            if (self.start_byte < new_end_byte) {
                self.start_byte = std.math.maxInt(u32);
                self.start_point = .{ .row = std.math.maxInt(u32), .column = std.math.maxInt(u32) };
            }
        } else if (self.start_byte > start_byte) {
            self.start_byte = start_byte;
            self.start_point = start_point;
        }
    }

    pub fn editWithInputEdit(self: *Range, input_edit: anytype) void {
        self.edit(
            input_edit.start_byte,
            input_edit.old_end_byte,
            input_edit.new_end_byte,
            input_edit.start_point,
            input_edit.old_end_point,
            input_edit.new_end_point,
        );
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
