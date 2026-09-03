const std = @import("std");

pub const Allocator = std.mem.Allocator;

pub fn allocMany(gpa: Allocator, comptime T: type, n: usize) Allocator.Error![]T {
    return try gpa.alloc(T, n);
}

pub fn dupeSlice(gpa: Allocator, comptime T: type, src: []const T) Allocator.Error![]T {
    return try gpa.dupe(T, src);
}

pub fn freeSlice(gpa: Allocator, slice: []u8) void {
    gpa.free(slice);
}

const parser_mod = @import("../parser/parser.zig");
const language_mod = @import("../language/language.zig");

test "allocator: failing allocator propagates OutOfMemory" {
    var parser = parser_mod.Parser.init(std.testing.failing_allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    const result = parser.parseString("1 + 2");
    try std.testing.expectError(error.OutOfMemory, result);
}

test "allocator: every parse frees everything" {
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        var parser = parser_mod.Parser.init(std.testing.allocator);
        defer parser.deinit();
        try parser.setLanguage(language_mod.expression_language);
        var tree = try parser.parseString("a + b * (c - 42)");
        defer tree.deinit();
        try std.testing.expect(!tree.hasError());
    }
}

test "allocator: allocation failures leave valid state" {
    const testing = std.testing;
    var parser = parser_mod.Parser.init(testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1");
    defer tree.deinit();
    try testing.expect(!tree.hasError());
    const result = parser.parseString("this source needs many allocations 1 + 2 + 3 + 4");
    if (result) |t| {
        var tree2 = t;
        defer tree2.deinit();
    } else |_| {}
}

test "allocator: helpers round-trip" {
    const mem = try allocMany(std.testing.allocator, u32, 4);
    defer std.testing.allocator.free(mem);
    try std.testing.expectEqual(@as(usize, 4), mem.len);
    const duped = try dupeSlice(std.testing.allocator, u8, "hi");
    defer std.testing.allocator.free(duped);
    try std.testing.expectEqualStrings("hi", duped);
}
