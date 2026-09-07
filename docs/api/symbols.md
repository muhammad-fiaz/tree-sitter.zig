---
description: Symbols API — ids, kinds, and metadata flags.
---

# Symbols

## Overview

Shared symbol vocabulary plus per-language symbol tables. Sources: `src/core/symbol.zig`, `src/language/symbols.zig`.

## Core

```zig
pub const Symbol = enum(u16) { end = 0, end_of_non_terminal_extra = 1, _ };
pub const SymbolId = u16;
pub const no_symbol: SymbolId  // maxInt(u16)
pub fn symbolFromId(id: SymbolId) Symbol
pub fn symbolToId(sym: Symbol) SymbolId
```

## Language symbols

```zig
pub const SymbolType = enum { terminal, non_terminal, external, end };
pub const SymbolMetadata = struct { visible: bool, named: bool, supertype: bool, extra: bool };
pub const SymbolInfo = struct { id: u16, name: []const u8, kind: SymbolType, metadata: SymbolMetadata };
```

## Related pages

[Symbols](/concepts/symbols), [Language](/api/language)
