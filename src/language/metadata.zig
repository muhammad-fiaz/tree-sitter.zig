const std = @import("std");

pub const abi_version_min: u32 = 13;
pub const abi_version_max: u32 = 15;
pub const current_abi_version: u32 = 15;

pub const Metadata = struct {
    name: []const u8 = "",
    abi_version: u32 = current_abi_version,
    version: []const u8 = "0.0.1",
    symbol_count: u16 = 0,
    state_count: u16 = 0,
    field_count: u16 = 0,
    supertype_count: u16 = 0,

    pub fn isCompatible(self: Metadata) bool {
        return self.abi_version >= abi_version_min and self.abi_version <= abi_version_max;
    }
};
