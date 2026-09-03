const std = @import("std");

pub const error_cost_per_skip: u32 = 1;
pub const error_cost_per_missing: u32 = 2;
pub const max_recovery_ops: u32 = 64;
pub const max_missing_inserts: u32 = 8;

pub const RecoveryKind = enum {
    skip_token,
    skip_byte,
    insert_missing,
    unwind,
    abort,
};

pub const RecoveryOp = struct {
    kind: RecoveryKind,
    symbol: u16 = 0,
    bytes: u32 = 0,
};

pub fn skipCost(bytes: u32) u32 {
    return bytes * error_cost_per_skip;
}

pub fn missingCost() u32 {
    return error_cost_per_missing;
}

test "recover: skip and missing costs" {
    try std.testing.expectEqual(@as(u32, 0), skipCost(0));
    try std.testing.expectEqual(@as(u32, 5), skipCost(5));
    try std.testing.expectEqual(@as(u32, error_cost_per_missing), missingCost());
    try std.testing.expect(max_recovery_ops > max_missing_inserts);
    try std.testing.expectEqual(@as(u32, 64), max_recovery_ops);
    try std.testing.expectEqual(@as(u32, 8), max_missing_inserts);
}
