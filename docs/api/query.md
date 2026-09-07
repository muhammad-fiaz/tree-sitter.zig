---
description: Query API — compiling patterns, captures, and pattern introspection.
---

# Query

## Overview

`Query` owns the compiled form of an S-expression query: pattern nodes, capture names, predicates. Source: `src/query/query.zig`.

## Lifecycle

```zig
var query = try parser.compileQuery("(identifier) @id"); // inherits parser allocator
defer query.deinit();
// standalone form: Query.compile(gpa, language, source)
```

## Methods

```zig
pub fn compile(gpa: Allocator, language: Language, source: []const u8) QueryError!Query
pub fn deinit(self: *Query) void
pub fn patternCount(self: *const Query) usize
pub fn captureCount(self: *const Query) usize
pub fn captureName(self: *const Query, index: u32) ?[]const u8
pub fn captureIndexForName(self: *const Query, name: []const u8) ?u32
pub fn nodes(self: *const Query) []const PatternNode
pub fn patterns(self: *const Query) []const Pattern
pub fn captureNames(self: *const Query) []const []const u8
```

`QueryError = Allocator.Error || QueryParseError || error{ InvalidLanguage }`, where parse errors include `UnexpectedEof`, `UnexpectedToken`, `InvalidSyntax`, and `InvalidPredicate`.

## Predicates

Parsed into `Predicate { kind, name, args }` with `PredicateKind` covering `eq` / `not_eq` / `any_eq` / `any_not_eq`, `match` / `not_match` / `any_match` / `any_not_match` (built-in subset: `. * + ? ^ $`, `[...]` classes, `\` escapes), `contains` / `not_contains` (evaluated extension), `any_of` / `not_any_of` (capture text equals one of the literals), and `is` / `is_not` (node properties via `checkProperty`: `named`, `anonymous`, `missing`, `error`, `extra`, `visible`; unknown properties never filter). Plain `eq`/`match` require **all** captured nodes to satisfy; `any-` variants require one. Argument shapes are validated at compile time (first argument a capture, `match?` pattern a literal, `any-of?` values literals-only) and predicate captures must be declared by node patterns (`InvalidCapture` otherwise). Evaluation is post-match in `QueryCursor.execute`. Full table: [Query Predicates](/guide/query-predicates).

## Directives and introspection

```zig
pub fn propertySettings(self: *const Query, pattern_index: usize) []const Setting
pub fn generalPredicates(self: *const Query, pattern_index: usize) []const Directive
pub fn captureQuantifier(self: *const Query, pattern_index: usize, capture_index: u32) ?Quantifier
```

`#set!` becomes per-pattern settings; every other `#name!` directive (`select-adjacent!`, `strip!`, unknown) is exposed structurally for higher-level code, mirroring upstream. `query.directives.selectAdjacent` / `stripText` apply the two known directives; `!field` assertions and `.` anchors (leading = first named child, between = named-adjacent, trailing = last named child) are enforced during matching.

## Ownership

Owns compiled representation; borrows allocator and language.

## Related APIs

[Query Cursor](/api/query-cursor); [Queries](/guide/queries)
