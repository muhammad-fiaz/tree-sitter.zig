---
description: Fields — named roles for children within a production.
---

# Fields

## Simple explanation

In `left + right`, both operands are expressions — but they play different *roles*. Fields name those roles so tools can ask for "the left side" directly instead of counting children.

## Technical explanation

`language/fields.zig` maps production ids to `(field name, child index)` bindings; `fieldIdForName` gives stable 1-based ids. Nodes resolve them through `childByFieldName` / `fieldNameForChild`, and query patterns constrain children with `left: (...)` syntax while cursors report `currentFieldName()`. The bundled grammar binds `left`/`right` on all four binary productions.

## Related pages

- [Navigating Nodes](/guide/navigating-nodes), [Queries](/guide/queries)
- [Fields API](/api/fields)
