import CoreText
import QuartzCore

/// A `CALayer` subclass that draws a `CTFrame` via Core Text.
///
/// The layer does **not** own document data. The cell sets `ctFrame` at
/// layout time (after bounds are known) and calls `setNeedsDisplay()`.
///
/// `needsFlip` controls whether the CG context is flipped at the start of
/// `draw(in:)`. macOS CALayer contexts are bottom-up; iOS contexts are
/// already top-down. `CTFrameDraw` always expects bottom-up, so:
/// - macOS (`needsFlip = true`): context is already bottom-up → draw directly.
/// - iOS (`needsFlip = false`): context is top-down → flip before drawing.
final class TextDrawingLayer: CALayer {

    /// The Core Text frame to draw. Set by the cell after layout.
    var ctFrame: CTFrame?

    /// macOS = true (layer context is bottom-up), iOS = false (already top-down).
    var needsFlip: Bool = true

    override init() {
        super.init()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? TextDrawingLayer {
            ctFrame = other.ctFrame
            needsFlip = other.needsFlip
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Clear rendering state. Called by the cell's `prepareForReuse`.
    func reset() {
        ctFrame = nil
        // `action(forKey:)` already suppresses animation on `contents`.
        contents = nil
    }

    override func action(forKey event: String) -> CAAction? {
        switch event {
        case "contents", "contentsScale":
            NSNull()
        default:
            super.action(forKey: event)
        }
    }

    // MARK: - Drawing

    override func draw(in ctx: CGContext) {
        guard let ctFrame else { return }

        if needsFlip {
            // macOS: context is bottom-up, CTFrameDraw expects bottom-up → draw directly.
            CTFrameDraw(ctFrame, ctx)
        } else {
            // iOS: context is top-down, CTFrameDraw expects bottom-up → flip.
            ctx.saveGState()
            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1, y: -1)
            CTFrameDraw(ctFrame, ctx)
            ctx.restoreGState()
        }
    }
}
