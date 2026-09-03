---
description: Parser API — lifecycle, languages, parsing, reuse, and queries.
---

# Parser

<VersionBadge />

## Overview

`Parser` owns the LR engine state: stacks, scratch buffers, reuse candidates, ranges, and the client allocator. One long-lived parser serves an entire editing session.

Import: `treesitter.Parser`. Facade source: `src/parser/parser.zig`.

## Lifecycle

```zig
var parser = treesitter.Parser.init(allocator);
defer parser.deinit();
```

## Methods

### init

```zig
pub fn init(gpa: std.mem.Allocator) Parser
```

Creates a parser holding `gpa` for all internal buffers. The only allocator handoff in typical use.

### deinit

```zig
pub fn deinit(self: *Parser) void
```

Frees stacks, scratch, candidates, and ranges.

### setLanguage

```zig
pub fn setLanguage(self: *Parser, language: Language) Language.Error!void
```

Loads grammar tables after ABI validation (`IncompatibleAbiVersion` on mismatch). Clears parser state.

### getLanguage

```zig
pub fn getLanguage(self: *const Parser) ?Language
```

### setLogger / setIncludedRanges / includedRanges

```zig
pub fn setLogger(self: *Parser, logger: Logger) void
pub fn setIncludedRanges(self: *Parser, ranges: []const Range) (Allocator.Error || error{InvalidRange})!void
pub fn includedRanges(self: *const Parser) []const Range
```

Ranges must be sorted and non-overlapping (`error.InvalidRange` otherwise) and are enforced by the lexer — see [Included Ranges](/guide/included-ranges).

### reset

```zig
pub fn reset(self: *Parser) void
```

Drops retained scratch capacity between unrelated workloads.

### parseString

```zig
pub fn parseString(self: *Parser, source: []const u8) ParserError!Tree
```

Full parse; the tree copies the source.

### parse

```zig
pub fn parse(self: *Parser, old_tree: ?*const Tree, edit: ?InputEdit, source: []const u8) ParserError!Tree
```

`null` old tree means a fresh parse. With an old tree plus edit, unaffected subtrees are reused; see `reused_node_count`.

### parseWithInput

```zig
pub fn parseWithInput(self: *Parser, old_tree: ?*const Tree, edit: ?InputEdit, reader_input: Input) ParserError!Tree
```

Pulls callback chunks, buffers them, and parses identically to memory input.

### parseStream

```zig
pub fn parseStream(self: *Parser, old_tree: ?*const Tree, edit: ?InputEdit, reader_input: Input) ParserError!Tree
```

True streaming: bytes are pulled on demand as the lexer advances — no pre-buffering — and the tree takes ownership of exactly the consumed prefix. With an old tree the input is buffered once so subtree reuse still applies. See [Custom Input](/guide/custom-input).

### queryCursor / compileQuery

```zig
pub fn queryCursor(self: *Parser) QueryCursor
pub fn compileQuery(self: *Parser, source: []const u8) QueryError!Query
```

Allocator-inheriting conveniences (`compileQuery` returns `InvalidLanguage` when no language is set).

### reused_node_count

```zig
reused_node_count: usize = 0
```

Subtrees spliced from the old tree by the most recent `parse`.

## Errors

`ParserError = Allocator.Error || error{ NoLanguage, Aborted, InvalidRange }`. Syntax problems never surface here — they become `ERROR`/`MISSING` nodes in the tree.

## Ownership

The parser borrows the allocator and the `Language` tables; it owns all internal buffers.

## Thread safety

Not synchronized. Use one parser per thread.

## Example

See [Your First Parser](/guide/first-parser) and [Incremental Parsing](/guide/incremental-parsing).

## Related APIs

[Tree](/api/tree), [Language](/api/language), [InputEdit](/api/input-edit), [Allocator](/api/allocator)
