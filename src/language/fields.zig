const std = @import("std");

pub const FieldBinding = struct {
    name: []const u8,
    child_index: u32,
    inherited: bool = false,
};

pub const FieldProduction = struct {
    production_id: u16,
    bindings: []const FieldBinding = &.{},
};

pub const FieldMap = struct {
    names: []const []const u8 = &.{},
    productions: []const FieldProduction = &.{},

    pub fn fieldIdForName(self: FieldMap, name: []const u8) ?u16 {
        for (self.names, 0..) |n, i| {
            if (std.mem.eql(u8, n, name)) return @as(u16, @intCast(i + 1));
        }
        return null;
    }

    pub fn fieldName(self: FieldMap, field_id: u16) ?[]const u8 {
        if (field_id == 0 or field_id > self.names.len) return null;
        return self.names[field_id - 1];
    }

    pub fn bindingsForProduction(self: FieldMap, production_id: u16) []const FieldBinding {
        for (self.productions) |p| {
            if (p.production_id == production_id) return p.bindings;
        }
        return &.{};
    }
};
