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
    private var currentAttrString: NSAttributedString?
    private var currentBlock: FlatBlock?

    public override func loadView() { self.view = LayerHostView() }

    public func configure(with block: FlatBlock, resolvedAttributes: ResolvedAttributes) {
        guard case .text(let inline) = block.content else { return }
        let attrStr = resolvedAttributes.applyStyle(to: inline.attributedString, kind: block.kind)

        currentAttrString = attrStr
        currentBlock = block

        let layer = ensureDrawingLayer()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = view.bounds
        layer.contentsScale = view.window?.backingScaleFactor ?? 2.0
        layer.needsFlip = true
        layer.block = block
        layer.ctFrame = makeCTFrame(attrString: attrStr, size: view.bounds.size)
        layer.setNeedsDisplay()
        CATransaction.commit()
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        drawingLayer?.reset()
        currentAttrString = nil
        currentBlock = nil
    }

    public override func viewDidLayout() {
        super.viewDidLayout()
        guard let dl = drawingLayer, dl.frame.size != view.bounds.size else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dl.frame = view.bounds
        if let attrStr = currentAttrString {
            dl.ctFrame = makeCTFrame(attrString: attrStr, size: view.bounds.size)
        }
        dl.setNeedsDisplay()
        CATransaction.commit()
    }

    private func ensureDrawingLayer() -> TextDrawingLayer {
        if let existing = drawingLayer { return existing }
        let l = TextDrawingLayer()
        view.layer?.addSublayer(l)
        drawingLayer = l
        return l
    }
}

// MARK: - iOS

#elseif canImport(UIKit)
import UIKit

public final class TextBlockCell: UICollectionViewCell {
    public static let reuseIdentifier = "TextBlockCell"

    private var drawingLayer: TextDrawingLayer?
    private var currentAttrString: NSAttributedString?
    private var currentBlock: FlatBlock?

    public func configure(with block: FlatBlock, resolvedAttributes: ResolvedAttributes) {
        guard case .text(let inline) = block.content else { return }
        let attrStr = resolvedAttributes.applyStyle(to: inline.attributedString, kind: block.kind)

        currentAttrString = attrStr
        currentBlock = block

        let layer = ensureDrawingLayer()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = contentView.bounds
        layer.contentsScale = UIScreen.main.scale
        layer.needsFlip = false
        layer.block = block
        layer.ctFrame = makeCTFrame(attrString: attrStr, size: contentView.bounds.size)
        layer.setNeedsDisplay()
        CATransaction.commit()
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        drawingLayer?.reset()
        currentAttrString = nil
        currentBlock = nil
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard let dl = drawingLayer, dl.frame.size != contentView.bounds.size else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dl.frame = contentView.bounds
        if let attrStr = currentAttrString {
            dl.ctFrame = makeCTFrame(attrString: attrStr, size: contentView.bounds.size)
        }
        dl.setNeedsDisplay()
        CATransaction.commit()
    }

    private func ensureDrawingLayer() -> TextDrawingLayer {
        if let existing = drawingLayer { return existing }
        let l = TextDrawingLayer()
        l.needsFlip = false
        contentView.layer.addSublayer(l)
        drawingLayer = l
        return l
    }
}
#endif
