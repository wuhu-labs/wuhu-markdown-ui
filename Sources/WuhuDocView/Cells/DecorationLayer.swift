import CoreText
import QuartzCore

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// A `CALayer` that draws gutter decorations (bullets, ordered numbers,
/// quote bars) for list items and blockquotes.
///
/// Positioned by the cell in the indent gutter to the left of the text
/// content. The layer's bounds define the gutter area; all drawing is
/// relative to those bounds.
final class DecorationLayer: CALayer {

    var decoration: Decoration?

    /// The height of the first line of text, used to vertically align
    /// bullet/number with the text baseline. Set by the cell at configure time.
    var firstLineHeight: CGFloat = 16

    override init() {
        super.init()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? DecorationLayer {
            decoration = other.decoration
            firstLineHeight = other.firstLineHeight
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func reset() {
        decoration = nil
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
        guard let decoration else { return }

        // Normalise to top-down coordinates. iOS CALayer contexts are already
        // top-down, but macOS contexts are bottom-up regardless of
        // isGeometryFlipped on a parent layer.
        #if canImport(AppKit)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        #endif
        defer {
            #if canImport(AppKit)
            ctx.restoreGState()
            #endif
        }

        let midX = bounds.width / 2
        let firstLineY = firstLineHeight

        switch decoration {
        case .bullet, .quoteBarAndBullet:
            let s: CGFloat = 5
            ctx.setFillColor(secondaryLabelColor)
            ctx.fillEllipse(in: CGRect(
                x: midX - s / 2, y: firstLineY - s / 2 - 2,
                width: s, height: s
            ))
            if case .quoteBarAndBullet = decoration {
                drawQuoteBar(in: ctx)
            }

        case .ordered(let n), .quoteBarAndOrdered(let n):
            let numStr = NSAttributedString(string: "\(n).", attributes: [
                .font: decorationFont,
                .foregroundColor: secondaryLabelColor,
            ])
            let line = CTLineCreateWithAttributedString(numStr)
            let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            // Center the number in the gutter
            let x = midX - lineWidth / 2
            ctx.saveGState()
            ctx.textMatrix = .identity
            // CTLineDraw expects bottom-up; flip from our normalised top-down context
            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1, y: -1)
            ctx.textPosition = CGPoint(x: x, y: bounds.height - firstLineY)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
            if case .quoteBarAndOrdered = decoration {
                drawQuoteBar(in: ctx)
            }

        case .quoteBar:
            drawQuoteBar(in: ctx)
        }
    }

    // MARK: - Quote Bar

    private func drawQuoteBar(in ctx: CGContext) {
        ctx.setFillColor(tertiaryLabelColor)
        ctx.fill(CGRect(x: 2, y: 2, width: 3, height: bounds.height - 4))
    }

    // MARK: - Platform Colors & Fonts

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
}
