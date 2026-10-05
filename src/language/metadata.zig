const std = @import("std");

pub const abiVersionMin: u32 = 13;
pub const abiVersionMax: u32 = 15;
pub const currentAbiVersion: u32 = 15;
pub const abi_version_min: u32 = abiVersionMin;
pub const abi_version_max: u32 = abiVersionMax;
pub const current_abi_version: u32 = currentAbiVersion;

pub const Metadata = struct {
    name: []const u8 = "",
    abi_version: u32 = currentAbiVersion,
    version: []const u8 = "0.0.2",
    symbol_count: u16 = 0,
    state_count: u16 = 0,
    field_count: u16 = 0,
    supertype_count: u16 = 0,

    pub fn abiVersion(self: Metadata) u32 {
        return self.abi_version;
    }

    pub fn isCompatible(self: Metadata) bool {
        return self.abi_version >= abiVersionMin and self.abi_version <= abiVersionMax;
    }
};
