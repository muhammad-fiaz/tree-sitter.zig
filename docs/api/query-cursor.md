---
description: QueryCursor API — execution, iteration, ranges, and limits.
---

# Query Cursor

<VersionBadge />

## Overview

`QueryCursor` executes a compiled query against a tree and owns the collected matches. Source: `src/query/cursor.zig`.

## Lifecycle

```zig
var cursor = parser.queryCursor(); // inherits parser allocator
defer cursor.deinit();
// standalone form: QueryCursor.init(gpa)
```

## Methods

```zig
pub fn deinit(self: *QueryCursor) void
pub fn reset(self: *QueryCursor) void            // clears results, keeps options + capacity
pub fn resetAll(self: *QueryCursor) void         // reset + default options
pub fn setByteRange(self: *QueryCursor, start: u32, end: u32) void
pub fn setPointRange(self: *QueryCursor, start: Point, end: Point) void
pub fn setMatchLimit(self: *QueryCursor, limit: u32) void
pub fn execute(self, language, patterns, nodes, capture_names, tree: *const Tree) Allocator.Error!void
pub fn nextMatch(self: *QueryCursor) ?*const Match
pub fn matchCount(self: *const QueryCursor) usize
pub fn remainingMatches(self: *const QueryCursor) usize
```

`Match { pattern_index: u32, captures: []Capture }`; `Capture { name, name_index, node }`. Set ranges/limits **before** `execute` (it resets results but preserves options).

## Ownership

Owns match storage; borrows allocator, query data, and the tree (matches reference tree nodes — keep the tree alive while reading them).

## Related APIs

[Query](/api/query); [Query Cursors](/guide/query-cursors)
