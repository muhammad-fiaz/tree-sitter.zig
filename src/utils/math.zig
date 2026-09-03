const std = @import("std");

pub fn min_usize(a: usize, b: usize) usize {
    return @min(a, b);
}

pub fn max_usize(a: usize, b: usize) usize {
    return @max(a, b);
}

pub fn min_u32(a: u32, b: u32) u32 {
    return @min(a, b);
}

pub fn max_u32(a: u32, b: u32) u32 {
    return @max(a, b);
}

pub fn clamp_usize(v: usize, lo: usize, hi: usize) usize {
    std.debug.assert(lo <= hi);
    return @min(@max(v, lo), hi);
}

pub fn addSaturating(a: u32, b: u32) u32 {
    const r = @addWithOverflow(a, b);
    return if (r[1] != 0) std.math.maxInt(u32) else r[0];
}

pub fn isPowerOfTwo(n: usize) bool {
    return std.math.isPowerOfTwo(n);
}

pub fn ceilPowerOfTwo(n: usize) usize {
    return std.math.ceilPowerOfTwo(usize, n) catch std.math.maxInt(usize);
}

pub fn castU32ToUsize(v: u32) usize {
    return @as(usize, @intCast(v));
}

pub fn castUsizeToU32(v: usize) ?u32 {
    if (v > std.math.maxInt(u32)) return null;
    return @as(u32, @intCast(v));
}
