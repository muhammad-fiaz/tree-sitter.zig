const std = @import("std");
const core = @import("../core/core.zig");

pub const no_parent: u32 = std.math.maxInt(u32);
pub const no_index: u32 = std.math.maxInt(u32);

pub const Subtree = struct {
    symbol: u16 = 0,
    production_id: u16 = 0,
    start_byte: u32 = 0,
    end_byte: u32 = 0,
    start_point: core.Point = .{},
    end_point: core.Point = .{},
    children_start: u32 = 0,
    child_count: u32 = 0,
    named_child_count: u32 = 0,
    descendant_count: u32 = 0,
    parent: u32 = no_parent,
    reuse_state: u16 = 0,
    named: bool = false,
    visible: bool = true,
    extra: bool = false,
    missing: bool = false,
    is_error: bool = false,
    has_error: bool = false,

    pub fn byteLen(self: Subtree) u32 {
        return self.end_byte - self.start_byte;
    }

    pub fn isLeaf(self: Subtree) bool {
        return self.child_count == 0;
    }
};

pub const SubtreePool = struct {
    nodes: std.ArrayList(Subtree) = .empty,
    child_indices: std.ArrayList(u32) = .empty,

    pub fn deinit(self: *SubtreePool, gpa: std.mem.Allocator) void {
        self.nodes.deinit(gpa);
        self.child_indices.deinit(gpa);
        self.* = undefined;
    }

    pub fn clearRetainingCapacity(self: *SubtreePool) void {
        self.nodes.clearRetainingCapacity();
        self.child_indices.clearRetainingCapacity();
    }

    pub fn pushNode(self: *SubtreePool, gpa: std.mem.Allocator, node: Subtree) std.mem.Allocator.Error!u32 {
        const index = self.nodes.items.len;
        if (index >= std.math.maxInt(u32)) return error.OutOfMemory;
        try self.nodes.append(gpa, node);
        return @as(u32, @intCast(index));
    }

    pub fn pushChildren(self: *SubtreePool, gpa: std.mem.Allocator, children: []const u32) std.mem.Allocator.Error!u32 {
        const start = self.child_indices.items.len;
        if (start >= std.math.maxInt(u32)) return error.OutOfMemory;
        try self.child_indices.appendSlice(gpa, children);
        return @as(u32, @intCast(start));
    }

    pub fn childrenOf(self: *const SubtreePool, node: Subtree) []const u32 {
        const start: usize = @as(usize, @intCast(node.children_start));
        const len: usize = @as(usize, @intCast(node.child_count));
        std.debug.assert(start + len <= self.child_indices.items.len);
        return self.child_indices.items[start .. start + len];
    }
};
