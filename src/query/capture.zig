const std = @import("std");
const tree_mod = @import("../tree/tree.zig");
const node_mod = @import("../tree/node.zig");

pub const Capture = struct {
    name: []const u8,
    name_index: u32,
    node: node_mod.Node,
};

pub const Match = struct {
    pattern_index: u32,
    captures: []Capture = &.{},
};
