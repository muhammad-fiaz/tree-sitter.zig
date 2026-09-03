---
description: Aliases and supertypes — grammar-level naming extensions.
---

# Aliases

## Simple explanation

Aliases let one grammar rule appear under different names in different contexts (for example, a generic `word` rule surfacing as `keyword` somewhere). Supertypes group several symbols under one abstract name for queries.

## Technical explanation

`language/aliases.zig` stores sparse per-production alias rules (`production_id`, `child_index`, rename-to symbol); `Language.supertype_map` lists each supertype's subtypes. Both behaviors are applied: when a rule is reduced, `makeInteriorNode` renames aliased children (so `nodeType()`, navigation, and queries observe the new name), and query matching expands supertype patterns to the supertype itself plus every registered subtype. The bundled s-expression grammar aliases the grouped-list production's middle child to `sequence` — `(sequence)` queries match grouped lists directly. Aliased subtrees keep their original reuse state, so they simply re-lex on the next edit instead of being spliced.

## Related pages

- [Symbols](/concepts/symbols), [Language Definition](/guide/language-definition)
- [Language API](/api/language)
