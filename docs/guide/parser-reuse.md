---
description: Reuse Parser instances across parses — retained capacity and reset semantics.
---

# Parser Reuse

## What you'll learn

- Why one long-lived parser beats a parser per parse.

## Complete example

```zig
var parser = treesitter.Parser.init(allocator);
defer parser.deinit();
try parser.setLanguage(lang);

var t1 = try parser.parseString("1 + 2");
defer t1.deinit();
var t2 = try parser.parseString("3 * 4");
defer t2.deinit();
```

## How it works

The parser keeps its state stack, token scratch space, reuse-candidate list, and included-range list between parses with retained capacity. Each `parse` clears lengths but keeps buffers, so steady-state editor workloads allocate only for genuinely new tree content. `setLanguage` also clears the stack (states belong to a grammar). Call `parser.reset()` to additionally drop retained scratch capacity between unrelated workloads.

## API used

- [Parser](/api/parser) — `parseString`, `parse`, `reset`.

## Related guides

- [Tree Reuse](/guide/tree-reuse), [Incremental Parsing](/guide/incremental-parsing), [Performance](/guide/performance)
