---
description: Error reference — every error union in tree-sitter.zig and what to do about each.
---

# Errors

## Parser

```zig
ParserError = Allocator.Error || error{ NoLanguage, Aborted }
```

- `NoLanguage` — `parse*` called before `setLanguage`.
- `Aborted` — reserved for cancelled parses.
- `OutOfMemory` — propagate; all partial state is cleaned up.

Syntax errors never appear here — they become tree nodes (see below).

## Language

```zig
Language.Error = error{ IncompatibleAbiVersion, InvalidSymbol }
```

- `IncompatibleAbiVersion` — tables target an ABI outside 13–15.

## Query

```zig
QueryError = Allocator.Error || QueryParseError || error{ InvalidLanguage }
QueryParseError = error{ OutOfMemory, UnexpectedEof, UnexpectedToken, InvalidSyntax, InvalidPredicate }
```

- `InvalidLanguage` — `compileQuery` without a language set.
- The parse errors pinpoint malformed query source; typos in `#predicate?` names are `InvalidPredicate`.

## Tree-level error inspection

```zig
tree.hasError() / node.hasError() / node.isError() / node.isMissing()
```

## Related pages

[Error Recovery](/guide/error-recovery), [Troubleshooting](/guide/troubleshooting)
