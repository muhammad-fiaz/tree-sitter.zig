const std = @import("std");
const node_mod = @import("node.zig");

/// S-expression serializer for trees: `(type child ...)` for named
/// interior nodes, `(type "text")` for named leaves, `"text"` for
/// anonymous tokens, and `(MISSING type)` for missing nodes.
///
/// Used by the differential conformance harness
/// (`src/debug/corpus/*.txt`, `zig build conformance`) and handy for
/// debugging. Output is canonical: single spaces, no newlines.
pub fn toSexp(gpa: std.mem.Allocator, node: node_mod.Node) std.mem.Allocator.Error![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(gpa);
    try writeNode(gpa, &out, node);
    return out.toOwnedSlice(gpa);
}

fn writeNode(gpa: std.mem.Allocator, out: *std.ArrayList(u8), node: node_mod.Node) std.mem.Allocator.Error!void {
    if (node.isMissing()) {
        try out.appendSlice(gpa, "(MISSING ");
        try out.appendSlice(gpa, node.nodeType());
        try out.append(gpa, ')');
        return;
    }
    if (!node.isNamed()) {
        try out.append(gpa, '"');
        try appendEscaped(gpa, out, node.text());
        try out.append(gpa, '"');
        return;
    }
    try out.append(gpa, '(');
    try out.appendSlice(gpa, node.nodeType());
    if (node.childCount() == 0) {
        try out.append(gpa, ' ');
        try out.append(gpa, '"');
        try appendEscaped(gpa, out, node.text());
        try out.append(gpa, '"');
    } else {
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            try out.append(gpa, ' ');
            try writeNode(gpa, out, node.child(i).?);
        }
    }
    try out.append(gpa, ')');
}

fn appendEscaped(gpa: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) std.mem.Allocator.Error!void {
    for (text) |b| {
        if (b == '"') {
            try out.appendSlice(gpa, "\\\"");
        } else if (b == '\\') {
            try out.appendSlice(gpa, "\\\\");
        } else if (b == '\n') {
            try out.appendSlice(gpa, "\\n");
        } else if (b == '\r') {
            try out.appendSlice(gpa, "\\r");
        } else if (b == '\t') {
            try out.appendSlice(gpa, "\\t");
        } else {
            try out.append(gpa, b);
        }
    }
}
