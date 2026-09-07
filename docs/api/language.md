---
description: Language API — symbols, tables, fields, aliases, metadata, and scanners.
---

# Language

## Overview

`Language` is borrowed grammar data. Source: `src/language/language.zig` (+ `symbols`, `tables`, `fields`, `aliases`, `metadata`).

## Struct fields

```zig
metadata: Metadata
symbols: []const SymbolInfo
token_matchers: []const TokenMatcher
extra_symbols: []const u16
word_token: u16
table: ParseTable
fields: FieldMap
aliases: AliasMap
supertypes: []const u16
supertype_map: []const SupertypeEntry  // { supertype: u16, subtypes: []const u16 }
external_scanner: ?ExternalScanner
```

`TokenMatcher = struct { symbol: u16, match: *const fn (source: []const u8, start: usize) ?usize }`.

`ExternalScanner = struct { payload: ?*anyopaque, scan: *const fn (...) ?ExternalToken, reset: ?*const fn (...) void }`.

## Methods

```zig
pub fn validate(self: Language) Error!void   // error.IncompatibleAbiVersion outside ABI 13–15
pub fn symbolCount(self: Language) usize
pub fn symbolInfo(self: Language, id: u16) ?SymbolInfo
pub fn symbolName(self: Language, id: u16) []const u8
pub fn symbolIsNamed / symbolIsVisible / symbolIsExtra / symbolIsSupertype
pub fn symbolForName(self: Language, name: []const u8, is_named: bool) ?u16
pub fn fieldIdForName / fieldNameForId
pub fn nextState(self: Language, state: u16, symbol: u16) u16
pub fn aliasFor(self: Language, production_id: u16, child_index: usize) ?Alias
pub fn subtypesOf(self: Language, supertype: u16) []const u16
```

`aliasFor` returns the rename applied when a production is reduced (see [Language Definition](/guide/language-definition)); `subtypesOf` lists the symbols a supertype pattern expands to in queries. `Error = error{ IncompatibleAbiVersion, InvalidSymbol }`.

## Bundled languages

```zig
treesitter.expression_language  // arithmetic: identifiers, numbers, +-*/, parens
treesitter.sexp_language        // nested parenthesized lists; aliases middle child to `sequence`
treesitter.json_language        // objects, arrays, strict strings/numbers, literals; key/value fields
treesitter.outline_language     // indentation-sensitive outlines via an external scanner
```

Scanner state is caller-owned (`treesitter.OutlineScanState`): copy the outline language, point its scanner payload at a live state value, and set the copy. Every parse starts with the scanner `reset` hook; see [External Scanners](/guide/external-scanners).

## Ownership

Always borrowed — typically comptime-known statics. The runtime never frees language data.

## Related APIs

[Parser](/api/parser) — `setLanguage`, [Symbols](/api/symbols), [Fields](/api/fields)
