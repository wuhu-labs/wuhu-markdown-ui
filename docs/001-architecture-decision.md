# Architecture Decision: Unified Block IR

**Date:** 2025-01-17
**Status:** Accepted

## Context

The current chat UI in wuhu-app uses `LazyVStack` with `MarkdownUI` for
rendering. This has several limitations:

- No control over inter-block margins (MarkdownUI owns its internal spacing)
- Entire message re-renders on each streaming token
- No path to cross-block text selection
- Cannot share the rendering engine between chat and document views

We need a high-performance rendering layer that works for both chat messages
and standalone documents.

## Decision

Build a **unified block IR** backed by `NSCollectionView` / `UICollectionView`
with a custom layout. The IR flattens all content — markdown blocks, message
headers, tool calls, user messages, document titles — into a single linear
sequence of typed blocks.

### Key Design Choices

1. **Messages as sections, blocks as cells.** Each message (or document) maps
   to a collection view section. Each block within that message is a cell.

2. **Flat block list.** Nested markdown structures (block quotes, lists) are
   flattened into a linear sequence with `indent` and `decoration` metadata.
   The custom layout uses these to compute leading offsets and gutter
   decorations.

3. **Custom layout, not compositional layout.** The layout computes all frames
   in `prepare()` using pre-measured block heights. No self-sizing negotiation.
   Margins are computed as a function of `(prevBlockKind, nextBlockKind)`.

4. **Core Text for text blocks.** Paragraphs, headings, list items, and
   blockquotes render via `CTFrame` in the cell's `draw(rect:)`. No SwiftUI
   hosting overhead for the common path.

5. **Opaque view cells for irreducible blocks.** Code blocks (need horizontal
   scroll) and tables (need grid layout) use hosted views. Images similarly.

6. **Custom blocks for domain-specific content.** Message headers, tool calls,
   user message bubbles, and document headers are all block types in the IR —
   the renderer doesn't know about "chat" vs "documents."

## Consequences

- The rendering engine is reusable across chat, docs, and "infinite doc" views
- Streaming invalidation is surgical (one cell, not one message)
- Full control over margins, spacing, and visual treatment per block type
- Cross-block text selection becomes feasible (future work)
- Higher implementation complexity vs. SwiftUI-only approach
