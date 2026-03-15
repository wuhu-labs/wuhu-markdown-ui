import CoreText
import QuartzCore

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// A `CALayer` subclass for Core Text rendering with gutter decorations.
///
/// The layer does **not** own the document data. The cell hands it a pre-built
/// `CTFrame` and block reference at configure time. On `prepareForReuse` the
/// cell clears these, and on the next configure they are set fresh for the
/// correct bounds.
///
/// `needsFlip` controls whether the CG context is flipped to top-down at the
/// start of `draw(in:)`. macOS CALayer contexts are bottom-up; iOS contexts
/// are already top-down.
final class TextDrawingLayer: CALayer {

    /// The Core Text frame to draw. Built by the cell at configure time for
    /// the cell's current bounds.
    var ctFrame: CTFrame?

    /// The block metadata (for decoration drawing). Not owned — just a reference
    /// set at configure time.
    var block: FlatBlock?

    /// macOS = true (layer context is bottom-up), iOS = false (already top-down).
    var needsFlip: Bool = true

    override init() {
        super.init()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? TextDrawingLayer {
            ctFrame = other.ctFrame
            block = other.block
            needsFlip = other.needsFlip
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Clear rendering state. Called by the cell's `prepareForReuse`.
    /// Clear `contents` too so a reused cell never shows stale text while
    /// waiting for the next configure/draw cycle.
    func reset() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ctFrame = nil
        block = nil
        contents = nil
        CATransaction.commit()
    }

    override func action(forKey event: String) -> CAAction? {
        switch event {
        case "contents", "contentsScale":
            // Text redraws should swap in immediately with no implicit fade.
            NSNull()
        default:
            super.action(forKey: event)
        }
    }

    // MARK: - Drawing

    override func draw(in ctx: CGContext) {
        if needsFlip {
            // macOS: flip to top-down so all drawing code uses y=0 at top
            ctx.saveGState()
            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1, y: -1)
            drawContent(in: ctx)
            ctx.restoreGState()
        } else {
            // iOS: already top-down
            drawContent(in: ctx)
        }
    }

    private func drawContent(in ctx: CGContext) {
        if let block {
            drawDecoration(block: block, in: ctx)
        }

        // CTFrameDraw always expects bottom-up — flip from our top-down context
        if let ctFrame {
            ctx.saveGState()
            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1, y: -1)
            CTFrameDraw(ctFrame, ctx)
            ctx.restoreGState()
        }
    }

    // MARK: - Decorations (top-down coordinates)

    private var secondaryLabelColor: CGColor {
        #if canImport(AppKit)
        NSColor.secondaryLabelColor.cgColor
        #else
        UIColor.secondaryLabel.cgColor
        #endif
    }

    private var tertiaryLabelColor: CGColor {
        #if canImport(AppKit)
        NSColor.tertiaryLabelColor.cgColor
        #else
        UIColor.tertiaryLabel.cgColor
        #endif
    }

    private var decorationFont: PlatformFont {
        #if canImport(AppKit)
        NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        #else
        UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        #endif
    }

    private func drawDecoration(block: FlatBlock, in ctx: CGContext) {
        guard let decoration = block.decoration else { return }
        let gutterX: CGFloat = -20
        let firstLineY: CGFloat = 14

        switch decoration {
        case .bullet, .quoteBarAndBullet:
            let s: CGFloat = 5
            ctx.setFillColor(secondaryLabelColor)
            ctx.fillEllipse(in: CGRect(
                x: gutterX + 4, y: firstLineY - s / 2 - 2, width: s, height: s
            ))
            if case .quoteBarAndBullet = decoration {
                drawQuoteBar(in: ctx, x: gutterX - 16)
            }

        case .ordered(let n), .quoteBarAndOrdered(let n):
            let numStr = NSAttributedString(string: "\(n).", attributes: [
                .font: decorationFont,
                .foregroundColor: secondaryLabelColor,
            ])
            let line = CTLineCreateWithAttributedString(numStr)
            ctx.saveGState()
            ctx.textMatrix = .identity
            // CTLineDraw needs bottom-up; flip from our top-down context
            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1, y: -1)
            ctx.textPosition = CGPoint(x: gutterX, y: bounds.height - firstLineY)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
            if case .quoteBarAndOrdered = decoration {
                drawQuoteBar(in: ctx, x: gutterX - 16)
            }

        case .quoteBar:
            drawQuoteBar(in: ctx, x: gutterX)
        }
    }

    private func drawQuoteBar(in ctx: CGContext, x: CGFloat) {
        ctx.setFillColor(tertiaryLabelColor)
        ctx.fill(CGRect(x: x, y: 2, width: 3, height: bounds.height - 4))
    }
}
