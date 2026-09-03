const std = @import("std");

pub const BitSet = std.DynamicBitSetUnmanaged;

pub fn bitSetInitEmpty(gpa: std.mem.Allocator, bit_count: usize) std.mem.Allocator.Error!BitSet {
    return try BitSet.initEmpty(gpa, bit_count);
}

pub fn bitSetDeinit(set: *BitSet, gpa: std.mem.Allocator) void {
    set.deinit(gpa);
}

pub fn bitSetUnion(a: *BitSet, gpa: std.mem.Allocator, b: BitSet) std.mem.Allocator.Error!void {
    if (b.bit_length > a.bit_length) {
        try a.resize(gpa, b.bit_length, false);
    }
    a.setUnion(b);
}

pub const StaticBitSet = std.StaticBitSet;

pub fn mask32(bits: u5) u32 {
    return @as(u32, 1) << bits;
}

pub fn hasFlag(value: u32, flag: u32) bool {
    return value & flag != 0;
}
