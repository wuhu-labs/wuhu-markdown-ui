# Streaming Invalidation Design

**Date:** 2025-01-17

## The Challenge

During LLM streaming, tokens arrive at high frequency. Each token potentially
changes the content and height of the currently-generating block. We need to
update the display at 60fps without triggering full layout passes.

## Strategy

### Incremental Re-parse

Rather than re-parsing the entire message on each token:

1. Buffer incoming tokens, flush at display-link cadence (~16ms)
2. On flush, re-parse from **two blocks back** from the end of the message
3. The two-block boundary handles transitions where a new block retroactively
   changes the previous block's boundary

### Lazy Height Invalidation

Each block has an `update(content:)` method that returns whether content
changed. After updating content, recompute the block's height:

```
Token arrives
  → buffer + flush at display-link rate
  → incremental re-parse (last 2 blocks)
  → block.update(newContent) → contentChanged?
  → recompute height → boundsChanged?
  → if contentChanged: reconfigureItems(at:)
  → if boundsChanged: layout.invalidateLayout(from:)
```

The critical optimization: **most tokens don't change the block height.**
Adding a word to a paragraph usually fits on the current line. In this case
we reconfigure (redraw the cell) but skip layout invalidation entirely.

### Post-Stream Finalization

When streaming ends, do one final full re-parse of the complete message.
This catches edge cases like:

- Reference-link definitions that resolve citations
- Block boundaries that shift with complete context
- Trailing whitespace cleanup

The finalized block array replaces the streaming blocks with a single
diff-and-update pass.

## Block ID Stability During Streaming

During streaming, blocks are only appended or the last block is mutated.
Insertions in the middle don't happen. This means IDs are trivially stable:

- `(messageID, index, blockKind)` — monotonically increasing index
- The last block is always "the mutable one"
- Previous blocks are frozen

On finalization, a one-time LCS diff maps old IDs to new positions,
preserving any interactive state (tool call expanded, etc.).
