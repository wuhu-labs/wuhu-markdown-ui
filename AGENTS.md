# WuhuMarkdownUI

High-performance document and chat rendering engine for macOS and iOS. This
replaces `LazyVStack` + `MarkdownUI` in `wuhu-app`.

## Build

This is an SPM package:

```bash
swift build
```

The demo app uses xcodegen:

```bash
cd Demo
xcodegen generate
open WuhuDocViewDemo.xcodeproj
```

Two schemes: `WuhuDocViewDemo` (macOS), `WuhuDocViewDemoiOS` (iOS).

## Architecture

Read the design docs in `docs/` for full context:

- `001-architecture-decision.md` — why this exists, key design choices
- `002-flattening-strategy.md` — how nested markdown becomes flat blocks
- `003-streaming-invalidation.md` — incremental re-parse during LLM streaming

### Core Concepts

- **FlatBlock**: one block = one collection view cell. Carries content,
  indent level, and gutter decoration.
- **BlockMeasuring protocol**: compute height from data (Core Text, arithmetic).
  `ViewBasedBlockMeasuring` extends it for blocks that need a SwiftUI view for
  measurement — same view used for rendering (single source of truth).
- **BlockMeasurerRegistry**: dispatches measurement by content type. Each
  measurer is a swappable property.
- **DocViewLayout**: custom `NSCollectionViewLayout`/`UICollectionViewLayout`.
  Computes all frames in `prepare()`. No self-sizing cells.
- **TextDrawingLayer**: `CALayer` subclass rendering via Core Text. GPU-cached
  bitmap, zero CPU during scroll.

### File Layout

```
Sources/WuhuDocView/
  BlockTypes.swift          — IR types (FlatBlock, BlockID, etc.)
  Cells/                    — Collection view cells (macOS + iOS)
  Measuring/                — BlockMeasuring protocols + concrete measurers
  DocViewLayout.swift       — Custom layout
  DocCollectionViewController.swift — Data source + cell factory
  DocView.swift             — SwiftUI wrapper
```

## Conventions

- Cross-platform: `#if canImport(AppKit)` / `#elseif canImport(UIKit)` in
  each file. Both platforms in the same file, not separate files.
- All layer property mutations wrapped in `CATransaction` with
  `setDisableActions(true)` to prevent implicit animations during reuse.
- Cell reuse: `prepareForReuse()` clears rendering state, `configure()`
  rebuilds for current bounds. Cells don't own document data.
- SwiftUI views (tables, custom blocks) go in `BlockViews.swift`. The
  measurer's `view(for:)` returns the same view the cell renders.

## Platforms

- macOS 15+
- iOS 18+
- Swift 6.0, strict concurrency

## Related

- `wuhu-app` — the consumer of this library (TCA app, macOS + iOS)
- Current chat UI: `WuhuApp/Sources/SessionThreadView.swift` (to be replaced)
