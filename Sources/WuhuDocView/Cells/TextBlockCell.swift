import CoreText
import QuartzCore

// MARK: - Helpers

/// Build a `CTFrame` from an attributed string for the given size.
func makeCTFrame(attrString: NSAttributedString, size: CGSize) -> CTFrame? {
    guard size.width > 0, size.height > 0 else { return nil }
    let framesetter = CTFramesetterCreateWithAttributedString(attrString)
    let path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
    return CTFramesetterCreateFrame(
        framesetter, CFRange(location: 0, length: attrString.length), path, nil
    )
}

// MARK: - macOS

#if canImport(AppKit)
import AppKit

public final class TextBlockCell: NSCollectionViewItem {
    public static let identifier = NSUserInterfaceItemIdentifier("TextBlockCell")

    private var drawingLayer: TextDrawingLayer?
    private var decorationLayer: DecorationLayer?
    private var currentAttrString: NSAttributedString?
    private var currentBlock: FlatBlock?
    private var indentWidth: CGFloat = 24

    public override func loadView() { self.view = LayerHostView() }

    public func configure(
        with block: FlatBlock,
        resolvedAttributes: ResolvedAttributes,
        indentWidth: CGFloat = 24
    ) {
        guard case .text(let inline) = block.content else { return }
        currentAttrString = resolvedAttributes.applyStyle(
            to: inline.attributedString, kind: block.kind
        )
        currentBlock = block
        self.indentWidth = indentWidth
        view.needsLayout = true
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        drawingLayer?.reset()
        decorationLayer?.reset()
        currentAttrString = nil
        currentBlock = nil
    }

    public override func viewDidLayout() {
        super.viewDidLayout()
        guard let attrStr = currentAttrString else { return }
        let bounds = view.bounds

        // Text layer
        let dl = ensureDrawingLayer()
        withNoAnimation {
            dl.frame = bounds
            dl.contentsScale = view.window?.backingScaleFactor ?? 2.0
            dl.needsFlip = true
            dl.ctFrame = makeCTFrame(attrString: attrStr, size: bounds.size)
            dl.setNeedsDisplay()
        }

        // Decoration layer
        layoutDecoration()
    }

    // MARK: - Decoration

    private func layoutDecoration() {
        guard let block = currentBlock, let decoration = block.decoration else {
            decorationLayer?.isHidden = true
            return
        }

        let dl = ensureDecorationLayer()
        let gutterWidth = indentWidth
        withNoAnimation {
            dl.isHidden = false
            dl.frame = CGRect(
                x: -gutterWidth, y: 0,
                width: gutterWidth, height: view.bounds.height
            )
            dl.contentsScale = view.window?.backingScaleFactor ?? 2.0
            dl.decoration = decoration
            dl.firstLineHeight = 14
            dl.setNeedsDisplay()
        }
    }

    // MARK: - Layer Management

    private func ensureDrawingLayer() -> TextDrawingLayer {
        if let existing = drawingLayer { return existing }
        let l = TextDrawingLayer()
        view.layer?.addSublayer(l)
        drawingLayer = l
        return l
    }

    private func ensureDecorationLayer() -> DecorationLayer {
        if let existing = decorationLayer { return existing }
        let l = DecorationLayer()
        view.layer?.addSublayer(l)
        decorationLayer = l
        return l
    }
}

// MARK: - iOS

#elseif canImport(UIKit)
import UIKit

public final class TextBlockCell: UICollectionViewCell {
    public static let reuseIdentifier = "TextBlockCell"

    private var drawingLayer: TextDrawingLayer?
    private var decorationLayer: DecorationLayer?
    private var currentAttrString: NSAttributedString?
    private var currentBlock: FlatBlock?
    private var indentWidth: CGFloat = 24

    public func configure(
        with block: FlatBlock,
        resolvedAttributes: ResolvedAttributes,
        indentWidth: CGFloat = 24
    ) {
        guard case .text(let inline) = block.content else { return }
        currentAttrString = resolvedAttributes.applyStyle(
            to: inline.attributedString, kind: block.kind
        )
        currentBlock = block
        self.indentWidth = indentWidth
        setNeedsLayout()
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        drawingLayer?.reset()
        decorationLayer?.reset()
        currentAttrString = nil
        currentBlock = nil
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard let attrStr = currentAttrString else { return }
        let bounds = contentView.bounds

        // Text layer
        let dl = ensureDrawingLayer()
        withNoAnimation {
            dl.frame = bounds
            dl.contentsScale = UIScreen.main.scale
            dl.needsFlip = false
            dl.ctFrame = makeCTFrame(attrString: attrStr, size: bounds.size)
            dl.setNeedsDisplay()
        }

        // Decoration layer
        layoutDecoration()
    }

    // MARK: - Decoration

    private func layoutDecoration() {
        guard let block = currentBlock, let decoration = block.decoration else {
            decorationLayer?.isHidden = true
            return
        }

        let dl = ensureDecorationLayer()
        let gutterWidth = indentWidth
        withNoAnimation {
            dl.isHidden = false
            dl.frame = CGRect(
                x: -gutterWidth, y: 0,
                width: gutterWidth, height: contentView.bounds.height
            )
            dl.contentsScale = UIScreen.main.scale
            dl.decoration = decoration
            dl.firstLineHeight = 14
            dl.setNeedsDisplay()
        }
    }

    // MARK: - Layer Management

    private func ensureDrawingLayer() -> TextDrawingLayer {
        if let existing = drawingLayer { return existing }
        let l = TextDrawingLayer()
        l.needsFlip = false
        contentView.layer.addSublayer(l)
        drawingLayer = l
        return l
    }

    private func ensureDecorationLayer() -> DecorationLayer {
        if let existing = decorationLayer { return existing }
        let l = DecorationLayer()
        contentView.layer.addSublayer(l)
        decorationLayer = l
        return l
    }
}
#endif
