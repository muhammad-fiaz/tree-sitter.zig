---
description: QueryCursor — executing queries, iterating matches, ranges, and limits.
---

# Query Cursors

## What you'll learn

- How to execute queries efficiently and control what comes back.

## Complete example

```zig
var cursor = parser.queryCursor();
defer cursor.deinit();

cursor.setByteRange(0, 80_000); // only matches intersecting this span
cursor.setMatchLimit(100); // stop after 100 matches
try cursor.execute(lang, query.patterns(), query.nodes(), query.captureNames(), &tree);

while (cursor.nextMatch()) |m| { ... }
```

## How it works

- `execute` walks the whole tree once per call and stores owned match/capture lists on the cursor; `nextMatch` then iterates without further tree access.
- `reset()` clears results but keeps capacity **and** your range/limit options; `resetAll()` also restores default options.
- Queries compile once and execute repeatedly; cursors are likewise reusable — set new options and `execute` again.

## Memory ownership

The cursor inherits the parser's allocator and owns its match storage until `reset` or `deinit`.

## API used

- [Query Cursor](/api/query-cursor), [Query](/api/query).

## Related guides

- [Queries](/guide/queries), [Performance](/guide/performance)
