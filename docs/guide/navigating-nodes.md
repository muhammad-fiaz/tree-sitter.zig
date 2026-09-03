---
description: Navigate syntax nodes — children, parents, siblings, fields, and byte-range lookup.
---

# Navigating Nodes

## What you'll learn

- Child, parent, and sibling navigation without allocation.
- Field access and byte-range descendant lookup.

## Complete example

```zig
var tree = try parser.parseString("1 + x");
defer tree.deinit();

const expr = tree.rootNode().child(0).?; // "expression"
const left = expr.namedChild(0).?; // "1"
const op = expr.child(1).?; // "+"
const right = expr.childByFieldName("right").?; // "x"

try std.testing.expect(left.parent().?.eql(expr));
try std.testing.expect(left.nextSibling().?.eql(op));
try std.testing.expect(left.nextNamedSibling().?.eql(right));

const found = tree.rootNode().descendantForByteRange(4, 5).?;
```

## How it works

- `child(i)` counts every child including punctuation; `namedChild(i)` skips anonymous tokens.
- `parent()` returns `null` at the root; siblings walk the parent's child list.
- `childByFieldName("left")` consults the language's field map for the node's production id — see [Fields](/concepts/fields).
- `descendantForByteRange` descends to the smallest node covering a range; `namedDescendantForByteRange` then walks up to the nearest named node.

## Performance considerations

All navigation is index arithmetic over the tree's pools — no heap allocation, no tree copying.

## API used

- [Node](/api/node) — full method table.

## Related guides

- [Understanding Trees](/guide/understanding-trees), [Tree Cursors](/guide/tree-cursors)
