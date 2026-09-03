const std = @import("std");

pub const Quantifier = enum {
    one,
    optional,
    zero_or_more,
    one_or_more,
};

pub const NodeKind = enum {
    named,
    anonymous,
    wildcard,
};

pub const PatternNode = struct {
    kind: NodeKind = .named,
    name: []const u8 = "",
    capture: ?u32 = null,
    field: ?[]const u8 = null,
    quantifier: Quantifier = .one,
    children: []u32 = &.{},
    child_fields: []?[]const u8 = &.{},
    /// Leading `.`: first child must be the first named child.
    /// On a child: `.` before it means no named siblings between the
    /// previous match and this one (anonymous nodes ignored).
    anchor_before: bool = false,
    /// Trailing `.`: last match must be the last named child.
    anchor_after: bool = false,
    /// `!field` assertions: the node must lack each listed field.
    negated_fields: [][]const u8 = &.{},
};

pub const PredicateKind = enum {
    eq,
    not_eq,
    any_eq,
    any_not_eq,
    match,
    not_match,
    any_match,
    any_not_match,
    contains,
    not_contains,
    is,
    is_not,
    any_of,
    not_any_of,
};

pub const PredicateArg = union(enum) {
    capture: u32,
    literal: []const u8,
};

pub const Predicate = struct {
    kind: PredicateKind,
    name: []const u8,
    args: []PredicateArg = &.{},
};

/// A `#set!` property setting: `key [value] [@capture]`, following the
/// upstream property form (at most one capture, key required).
pub const Setting = struct {
    key: []const u8,
    value: ?[]const u8 = null,
    capture: ?u32 = null,
};

/// A `#name!` directive (`select-adjacent!`, `strip!`, or anything
/// unknown): operator plus raw args, exposed structurally for
/// higher-level code — mirroring upstream, where directives are parsed
/// but not evaluated by the query engine itself.
pub const Directive = struct {
    operator: []const u8,
    args: []PredicateArg = &.{},
};

pub const Pattern = struct {
    root: u32,
    predicates: []Predicate = &.{},
    settings: []Setting = &.{},
    directives: []Directive = &.{},
    is_rooted: bool = false,
};
