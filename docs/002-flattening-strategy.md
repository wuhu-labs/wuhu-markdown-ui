# Block Flattening Strategy

**Date:** 2025-01-17

## The Problem

`UICollectionView` / `NSCollectionView` is a flat list of cells. Markdown has
nested structures: block quotes containing lists containing paragraphs. We
need a flattening strategy that preserves visual fidelity while producing a
linear cell sequence.

## Approach

Every node in the markdown AST becomes a `FlatBlock` carrying:

- **`indent: Int`** — nesting depth, controls leading offset
- **`decoration: Decoration?`** — gutter decoration (quote bar, bullet, number)

The flattener walks the AST depth-first. Each leaf block-level node emits a
`FlatBlock`. Container nodes (block quotes, list items) increment the indent
counter and set the decoration for their first child.

## Examples

### Simple List

```markdown
- Item one
- Item two
  - Nested item
- Item three
```

Flattens to:

| Block | Indent | Decoration |
|-------|--------|------------|
| paragraph("Item one") | 1 | bullet |
| paragraph("Item two") | 1 | bullet |
| paragraph("Nested item") | 2 | bullet |
| paragraph("Item three") | 1 | bullet |

### Block Quote with List

```markdown
> Here is a quoted section
>
> - First point
> - Second point
>
> And a conclusion
```

Flattens to:

| Block | Indent | Decoration |
|-------|--------|------------|
| paragraph("Here is a quoted section") | 1 | quoteBar |
| paragraph("First point") | 1 | quoteBarAndBullet |
| paragraph("Second point") | 1 | quoteBarAndBullet |
| paragraph("And a conclusion") | 1 | quoteBar |

### Multi-Paragraph List Item

```markdown
- First paragraph of item.

  Second paragraph, still item one.

- Next item.
```

Flattens to:

| Block | Indent | Decoration |
|-------|--------|------------|
| paragraph("First paragraph of item.") | 1 | bullet |
| paragraph("Second paragraph, still item one.") | 1 | none |
| paragraph("Next item.") | 1 | bullet |

The bullet marks the item start. Continuation blocks share the indent but
have no bullet decoration.

## Pathological Nesting

Deeply nested structures like `> > > > >` simply produce high indent values.
The text area gets narrower. This is correct behavior — pathological input
produces constrained output. No special-casing needed.

## Irreducible Blocks

Code blocks and tables cannot be meaningfully flattened further. They become
single cells regardless of nesting depth, carrying the accumulated indent.

A code block inside a block quote inside a list item:

```markdown
> - Here's some code:
>
>   ```swift
>   let x = 42
>   ```
```

Produces:

| Block | Indent | Decoration |
|-------|--------|------------|
| paragraph("Here's some code:") | 1 | quoteBarAndBullet |
| codeBlock("swift", "let x = 42") | 2 | quoteBar |
