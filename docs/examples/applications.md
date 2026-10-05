---
description: Application patterns — syntax highlighting, code navigation, and structural search.
---

# Applications

## What you'll learn

- Implementing syntax highlighting by classifying leaf tokens during tree traversal.
- Navigating code structures and extracting symbols for IDE integration.
- Composing incremental parsing and queries into real-world developer tools.

## Complete example: Syntax Highlighting

This example demonstrates how an editor or syntax highlighter walks a syntax tree with `TreeCursor`, identifies leaf tokens, and classifies them into semantic highlight categories (`variable`, `constant`, `operator`):

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expressionLanguage;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    const source = "price * (count + 1)";
    var tree = try parser.parseString(source);
    defer tree.deinit();

    var cursor = tree.cursor();
    defer cursor.deinit();

    std.debug.print("Highlighting tokens for: {s}\n", .{source});
    outer: while (true) {
        const node = cursor.currentNode();
        // Classify leaf tokens (nodes without children)
        if (node.childCount() == 0) {
            const kind = if (std.mem.eql(u8, node.nodeType(), "identifier"))
                "variable"
            else if (std.mem.eql(u8, node.nodeType(), "number"))
                "constant"
            else
                "operator";
            std.debug.print("span [{d: >2}..{d: >2}]: {s: <10} => {s}\n", .{
                node.startByte(),
                node.endByte(),
                node.text(),
                kind,
            });
        }
        if (cursor.gotoFirstChild()) continue;
        while (true) {
            if (cursor.gotoNextSibling()) break;
            if (!cursor.gotoParent()) break :outer;
        }
    }
}
```

## Running the example

```bash
zig build run-highlight
```

## Expected output

```text
Highlighting tokens for: price * (count + 1)
span [ 0.. 5]: price      => variable
span [ 6.. 7]: *          => operator
span [ 8.. 9]: (          => operator
span [ 9..14]: count      => variable
span [15..16]: +          => operator
span [17..18]: 1          => constant
span [18..19]: )          => operator
```

## Common Application Patterns

### 1. Code Navigation and Definition Jump

Use `node.descendantForByteRange(cursor_offset, cursor_offset)` to find the smallest AST node at the user's cursor. From there, inspect `node.parent()` to determine the enclosing construct, or read `node.childByFieldName(...)` to extract definition targets.

### 2. Structural Search and Linting

Combine queries with predicates to locate code patterns regardless of whitespace or formatting:

```zig
var query = try parser.compileQuery("((term (identifier) @a (identifier) @b) (#eq? @a @b))");
defer query.deinit();
```

### 3. Keystroke-Driven Editor Loop

1. Receive user keystroke with replacement range.
2. Construct an `InputEdit` and apply it to the existing tree.
3. Call `parser.parse(&old_tree, edit, new_buffer)`.
4. Call `old_tree.getChangedRanges(&new_tree)` to update syntax highlighting only for dirty screen lines.

## Related guides

- [Use Cases Overview](/use-cases/)
- [Syntax Highlighting Use Case](/use-cases/syntax-highlighting)
- [Code Editor Integration](/use-cases/code-editor)
