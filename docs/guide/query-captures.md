---
description: Query captures — naming matched nodes and reading match results.
---

# Query Captures

## What you'll learn

- How `@name` captures attach to pattern nodes and how to read them from matches.

## Complete example

```zig
var query = try parser.compileQuery("(term left: (_) @l right: (_) @r)");
defer query.deinit();
// ... execute ...
const m = cursor.nextMatch().?;
// m.pattern_index, m.captures[0].name, m.captures[0].node
```

A `Match` carries its `pattern_index` (which top-level pattern matched) and a slice of `Capture` values, each with the capture `name`, its `name_index`, and the matched `Node`.

## How it works

Capture names are interned once at compile time (`captureIndexForName` / `captureName`). During matching, every pattern node with a capture records `(name, node)` into the matcher's scratch list; on success the slice is duplicated into the cursor's match storage, so matches stay valid while the cursor lives even as matching continues.

## API used

- [Query](/api/query) — `captureCount`, `captureName`, `captureIndexForName`; [Query Cursor](/api/query-cursor) — `nextMatch`, `matchCount`.

## Related guides

- [Queries](/guide/queries), [Query Cursors](/guide/query-cursors)
