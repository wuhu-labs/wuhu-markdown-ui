#if canImport(AppKit)
import AppKit

/// A minimal `NSView` with a flipped-geometry root layer. Sublayer y=0 is at
/// the top, matching NSCollectionView's top-down cell placement. All rendering
/// goes through CALayer sublayers — no NSView.draw(_:) anywhere.
final class LayerHostView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.isGeometryFlipped = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
#endif
