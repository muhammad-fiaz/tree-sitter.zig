const std = @import("std");

pub fn List(comptime T: type) type {
    return std.ArrayList(T);
}

pub fn HashMap(comptime K: type, comptime V: type) type {
    return std.AutoHashMap(K, V);
}

pub fn StringMap(comptime V: type) type {
    return std.StringHashMap(V);
}

pub fn containsSlice(comptime T: type, haystack: []const T, needle: T) bool {
    for (haystack) |item| {
        if (std.meta.eql(item, needle)) return true;
    }
    return false;
}

pub fn countSlice(comptime T: type, haystack: []const T, needle: T) usize {
    var n: usize = 0;
    for (haystack) |item| {
        if (std.meta.eql(item, needle)) n += 1;
    }
    return n;
}

pub fn sortAscending(comptime T: type, items: []T, context: anytype, comptime lessThan: fn (@TypeOf(context), T, T) bool) void {
    std.mem.sort(T, items, context, lessThan);
}

pub fn binarySearch(comptime T: type, items: []const T, key: T, context: anytype, comptime order: fn (@TypeOf(context), T, T) std.math.Order) ?usize {
    var lo: usize = 0;
    var hi: usize = items.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        switch (order(context, items[mid], key)) {
            .lt => lo = mid + 1,
            .gt => hi = mid,
            .eq => return mid,
        }
    }
    return null;
}
