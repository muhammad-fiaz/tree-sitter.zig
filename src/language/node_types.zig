const std = @import("std");

pub const ChildType = struct {
    type_name: []const u8,
    named: bool = true,
};

pub const ChildrenInfo = struct {
    multiple: bool = false,
    required: bool = false,
    types: []ChildType = &.{},
};

pub const FieldInfo = struct {
    multiple: bool = false,
    required: bool = false,
    types: []ChildType = &.{},
};

pub const FieldEntry = struct {
    name: []const u8,
    info: FieldInfo,
};

pub const NodeType = struct {
    type_name: []const u8,
    named: bool = true,
    fields: []FieldEntry = &.{},
    children: ?ChildrenInfo = null,
    subtypes: []ChildType = &.{},

    pub fn getField(self: *const NodeType, field_name: []const u8) ?*const FieldInfo {
        for (self.fields) |*f| {
            if (std.mem.eql(u8, f.name, field_name)) return &f.info;
        }
        return null;
    }
};

pub const NodeTypes = struct {
    allocator: std.mem.Allocator,
    types: []NodeType,

    pub fn parseJSON(allocator: std.mem.Allocator, json_text: []const u8) !NodeTypes {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_text, .{});
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .array) return error.InvalidNodeTypesJSON;

        var type_list = std.ArrayList(NodeType).empty;
        errdefer {
            for (type_list.items) |*t| deinitNodeType(allocator, t);
            type_list.deinit(allocator);
        }

        for (root.array.items) |item| {
            if (item != .object) continue;
            const obj = item.object;

            const type_val = obj.get("type") orelse continue;
            if (type_val != .string) continue;

            const named_val = obj.get("named");
            const named = if (named_val) |v| (if (v == .bool) v.bool else true) else true;

            const owned_type_name = try allocator.dupe(u8, type_val.string);
            errdefer allocator.free(owned_type_name);

            // Fields
            var fields_list = std.ArrayList(FieldEntry).empty;
            errdefer {
                for (fields_list.items) |*f| {
                    allocator.free(f.name);
                    for (f.info.types) |ct| allocator.free(ct.type_name);
                    allocator.free(f.info.types);
                }
                fields_list.deinit(allocator);
            }

            if (obj.get("fields")) |fields_val| {
                if (fields_val == .object) {
                    var fit = fields_val.object.iterator();
                    while (fit.next()) |fentry| {
                        const fname = try allocator.dupe(u8, fentry.key_ptr.*);
                        errdefer allocator.free(fname);

                        var finfo = FieldInfo{};
                        if (fentry.value_ptr.* == .object) {
                            const f_obj = fentry.value_ptr.object;
                            if (f_obj.get("multiple")) |m| if (m == .bool) {
                                finfo.multiple = m.bool;
                            };
                            if (f_obj.get("required")) |r| if (r == .bool) {
                                finfo.required = r.bool;
                            };
                            if (f_obj.get("types")) |tarr| if (tarr == .array) {
                                var ct_list = std.ArrayList(ChildType).empty;
                                errdefer {
                                    for (ct_list.items) |ct| allocator.free(ct.type_name);
                                    ct_list.deinit(allocator);
                                }
                                for (tarr.array.items) |titem| {
                                    if (titem == .object) {
                                        if (titem.object.get("type")) |tname| if (tname == .string) {
                                            const ct_named = if (titem.object.get("named")) |nv| (if (nv == .bool) nv.bool else true) else true;
                                            try ct_list.append(allocator, .{
                                                .type_name = try allocator.dupe(u8, tname.string),
                                                .named = ct_named,
                                            });
                                        };
                                    }
                                }
                                finfo.types = try ct_list.toOwnedSlice(allocator);
                            };
                        }

                        try fields_list.append(allocator, .{
                            .name = fname,
                            .info = finfo,
                        });
                    }
                }
            }

            // Children
            var children_info: ?ChildrenInfo = null;
            if (obj.get("children")) |cval| {
                if (cval == .object) {
                    const c_obj = cval.object;
                    var cinfo = ChildrenInfo{};
                    if (c_obj.get("multiple")) |m| if (m == .bool) {
                        cinfo.multiple = m.bool;
                    };
                    if (c_obj.get("required")) |r| if (r == .bool) {
                        cinfo.required = r.bool;
                    };
                    if (c_obj.get("types")) |tarr| if (tarr == .array) {
                        var ct_list = std.ArrayList(ChildType).empty;
                        errdefer {
                            for (ct_list.items) |ct| allocator.free(ct.type_name);
                            ct_list.deinit(allocator);
                        }
                        for (tarr.array.items) |titem| {
                            if (titem == .object) {
                                if (titem.object.get("type")) |tname| if (tname == .string) {
                                    const ct_named = if (titem.object.get("named")) |nv| (if (nv == .bool) nv.bool else true) else true;
                                    try ct_list.append(allocator, .{
                                        .type_name = try allocator.dupe(u8, tname.string),
                                        .named = ct_named,
                                    });
                                };
                            }
                        }
                        cinfo.types = try ct_list.toOwnedSlice(allocator);
                    };
                    children_info = cinfo;
                }
            }

            // Subtypes
            var subtypes_list = std.ArrayList(ChildType).empty;
            errdefer {
                for (subtypes_list.items) |ct| allocator.free(ct.type_name);
                subtypes_list.deinit(allocator);
            }
            if (obj.get("subtypes")) |sval| {
                if (sval == .array) {
                    for (sval.array.items) |sitem| {
                        if (sitem == .object) {
                            if (sitem.object.get("type")) |tname| if (tname == .string) {
                                const ct_named = if (sitem.object.get("named")) |nv| (if (nv == .bool) nv.bool else true) else true;
                                try subtypes_list.append(allocator, .{
                                    .type_name = try allocator.dupe(u8, tname.string),
                                    .named = ct_named,
                                });
                            };
                        }
                    }
                }
            }

            try type_list.append(allocator, .{
                .type_name = owned_type_name,
                .named = named,
                .fields = try fields_list.toOwnedSlice(allocator),
                .children = children_info,
                .subtypes = try subtypes_list.toOwnedSlice(allocator),
            });
        }

        return .{
            .allocator = allocator,
            .types = try type_list.toOwnedSlice(allocator),
        };
    }

    fn deinitNodeType(allocator: std.mem.Allocator, node_type: *NodeType) void {
        allocator.free(node_type.type_name);
        for (node_type.fields) |*f| {
            allocator.free(f.name);
            for (f.info.types) |ct| allocator.free(ct.type_name);
            allocator.free(f.info.types);
        }
        allocator.free(node_type.fields);
        if (node_type.children) |*c| {
            for (c.types) |ct| allocator.free(ct.type_name);
            allocator.free(c.types);
        }
        for (node_type.subtypes) |ct| allocator.free(ct.type_name);
        allocator.free(node_type.subtypes);
    }

    pub fn deinit(self: *NodeTypes) void {
        for (self.types) |*t| {
            deinitNodeType(self.allocator, t);
        }
        self.allocator.free(self.types);
    }

    pub fn findType(self: *const NodeTypes, name: []const u8) ?*const NodeType {
        for (self.types) |*t| {
            if (std.mem.eql(u8, t.type_name, name)) return t;
        }
        return null;
    }
};

test "node_types: parse basic node types json" {
    const json =
        \\[
        \\  {
        \\    "type": "binary_expression",
        \\    "named": true,
        \\    "fields": {
        \\      "left": {
        \\        "multiple": false,
        \\        "required": true,
        \\        "types": [{ "type": "expression", "named": true }]
        \\      },
        \\      "right": {
        \\        "multiple": false,
        \\        "required": true,
        \\        "types": [{ "type": "expression", "named": true }]
        \\      }
        \\    }
        \\  },
        \\  {
        \\    "type": "identifier",
        \\    "named": true
        \\  }
        \\]
    ;

    var nt = try NodeTypes.parseJSON(std.testing.allocator, json);
    defer nt.deinit();

    try std.testing.expectEqual(@as(usize, 2), nt.types.len);
    const be = nt.findType("binary_expression");
    try std.testing.expect(be != null);
    try std.testing.expect(be.?.named);
    try std.testing.expectEqual(@as(usize, 2), be.?.fields.len);

    const left = be.?.getField("left");
    try std.testing.expect(left != null);
    try std.testing.expect(left.?.required);
    try std.testing.expect(!left.?.multiple);
    try std.testing.expectEqual(@as(usize, 1), left.?.types.len);
    try std.testing.expectEqualStrings("expression", left.?.types[0].type_name);

    const id = nt.findType("identifier");
    try std.testing.expect(id != null);
    try std.testing.expect(id.?.named);
}
