const std = @import("std");

pub fn assertOk(cond: bool) void {
    std.debug.assert(cond);
}

pub fn unreachableCode() noreturn {
    std.debug.panic("unreachable code reached", .{});
}

pub fn checkIndex(len: usize, index: usize) void {
    std.debug.assert(index < len);
}

pub fn checkRange(len: usize, start: usize, end: usize) void {
    std.debug.assert(start <= end);
    std.debug.assert(end <= len);
}
