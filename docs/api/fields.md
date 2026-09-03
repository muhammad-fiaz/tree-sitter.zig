---
description: Fields API — production bindings and name/id conversion.
---

# Fields

<VersionBadge />

## Overview

Field maps bind production ids to `(name, child index)` roles. Source: `src/language/fields.zig`.

## Types

```zig
pub const FieldBinding = struct { name: []const u8, child_index: u32, inherited: bool };
pub const FieldProduction = struct { production_id: u16, bindings: []const FieldBinding };
pub const FieldMap = struct {
    names: []const []const u8,
    productions: []const FieldProduction,
    pub fn fieldIdForName(self: FieldMap, name: []const u8) ?u16   // 1-based, null when absent
    pub fn fieldName(self: FieldMap, field_id: u16) ?[]const u8
    pub fn bindingsForProduction(self: FieldMap, production_id: u16) []const FieldBinding
};
```

## Related pages

[Fields](/concepts/fields), [Navigating Nodes](/guide/navigating-nodes), [Language](/api/language)
