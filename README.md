# WuhuMarkdownUI

High-performance document and chat rendering engine for macOS and iOS.

Replaces `LazyVStack` + [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) with a `NSCollectionView`/`UICollectionView`-backed engine using Core Text for text rendering. Designed for streaming LLM chat UIs where memory usage and scroll performance matter.

## Architecture

Every piece of content — markdown paragraphs, headings, code blocks, tables, message headers, tool calls — is a **block** in a flat IR. The collection view renders one cell per block.

```
Markdown AST ��� Flattener → [FlatBlock] → DocViewLayout → Collection View
```

- **Text blocks** (paragraphs, headings, list items, blockquotes) → Core Text via `CALayer.draw(in:)`. GPU-cached bitmap, zero CPU during scroll.
- **Code blocks** → `NSTextView`/`UITextView` for horizontal scroll and text selection.
- **Tables, custom blocks** → SwiftUI views hosted in cells, measured via `ViewBasedBlockMeasuring` protocol.
- **Nested structures** (lists, blockquotes) → flattened to indented paragraphs with gutter decorations (bullets, numbers, quote bars).

### Key Design Decisions

- **Custom layout** — `DocViewLayout` computes all frames in `prepare()`. No self-sizing cells, no compositional layout.
- **Protocol-based measurement** — `BlockMeasuring` for direct computation (Core Text, arithmetic), `ViewBasedBlockMeasuring` for SwiftUI view measurement. Same view used for both measurement and rendering.
- **Messages as sections, blocks as cells** — natural mapping for diffable data source.
- **Cross-platform** — macOS (`NSCollectionView`) and iOS (`UICollectionView`) from the same source.

## Package Structure

```
Sources/WuhuDocView/
  BlockTypes.swift              — FlatBlock, BlockID, BlockKind, Decoration, BlockContent
  BlockViews.swift              — SwiftUI views for custom blocks (headers, tables, tool calls)
  DocSection.swift              — DocSection, Document
  DocumentBuilder.swift         — Convenience constructors
  DocView.swift                 — SwiftUI wrapper (NSViewControllerRepresentable / UIViewControllerRepresentable)
  DocViewLayout.swift           — Custom collection view layout (macOS + iOS)
  DocCollectionViewController.swift — View controller (macOS + iOS)
  ResolvedAttributes.swift      — Theming: fonts, colors per block kind
  SpacingTable.swift            — Context-sensitive inter-block margins

  Cells/
    LayerHostView.swift         — macOS: flipped-geometry NSView for layer hosting
    TextDrawingLayer.swift      — CALayer subclass for Core Text + gutter decorations
    TextBlockCell.swift         — Text cell (macOS + iOS)
    CodeBlockCell.swift         — Code cell with horizontal scroll
    HostedSwiftUICell.swift     — Generic SwiftUI hosting cell
    ThematicBreakCell.swift     — Horizontal rule

  Measuring/
    BlockMeasuring.swift        — BlockMeasuring + ViewBasedBlockMeasuring protocols
    BlockMeasurerRegistry.swift — Dispatches measurement by content type
    TextBlockMeasurer.swift     — Core Text measurement
    CodeBlockMeasurer.swift     — Line count arithmetic
    ConstantHeightMeasurer.swift — Fixed height (thematic breaks, image placeholders)
    TableBlockMeasurer.swift    — SwiftUI view measurement for tables
    CustomBlockMeasurer.swift   — SwiftUI view measurement for custom blocks

Demo/                           — xcodegen demo app (macOS + iOS targets)
docs/                           — Architecture decision records
```

## Demo

```bash
cd Demo
xcodegen generate
open WuhuDocViewDemo.xcodeproj
```

Two schemes: `WuhuDocViewDemo` (macOS) and `WuhuDocViewDemoiOS` (iOS).

## Performance

In testing against the previous `LazyVStack` + `MarkdownUI` approach:
- Memory dropped from ~700MB to ~40MB for large conversations
- Scroll is 60fps — text cells are GPU-cached bitmaps, no CPU work during scroll
- Streaming invalidation is surgical: one cell reconfigure, not full message re-render

## Status

This is an active work-in-progress. See [docs/](docs/) for design documents and the next steps below.

## Next Steps

- [ ] Markdown parsing: `swift-markdown` `Document` → `[FlatBlock]` flattener
- [ ] Streaming path: incremental re-parse, `reconfigureItems`, scroll anchoring, display-link batching
- [ ] `BlockView` protocol for persistent view instances with `update(content:)` and height-change reporting
- [ ] Cross-block text selection
- [ ] Integration into wuhu-app as replacement for current chat UI
- [ ] Syntax highlighting for code blocks (tree-sitter or similar)

## License

Private — wuhu-labs internal.
