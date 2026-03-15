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

/// Hit-test a `CTFrame` to find the string index at a given point.
///
/// `point` is in the CTFrame's coordinate system (origin bottom-left).
/// Returns the string index, or `nil` if the point is outside all lines.
private func characterIndex(in ctFrame: CTFrame, at point: CGPoint) -> CFIndex? {
    let lines = CTFrameGetLines(ctFrame) as! [CTLine]
    guard !lines.isEmpty else { return nil }

    var origins = [CGPoint](repeating: .zero, count: lines.count)
    CTFrameGetLineOrigins(ctFrame, CFRange(location: 0, length: 0), &origins)

    for (i, line) in lines.enumerated() {
        let origin = origins[i]
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let lineRect = CGRect(
            x: origin.x,
            y: origin.y - descent,
            width: width,
            height: ascent + descent + leading
        )
        guard lineRect.contains(point) else { continue }
        let localX = point.x - origin.x
        return CTLineGetStringIndexForPosition(line, CGPoint(x: localX, y: 0))
    }
    return nil
}

/// Extract the URL from an `NSAttributedString` at the given index, if any.
private func linkURL(in attrString: NSAttributedString, at index: CFIndex) -> URL? {
    guard index >= 0, index < attrString.length else { return nil }
    return attrString.attribute(.link, at: index, effectiveRange: nil) as? URL
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
    private var trackingArea: NSTrackingArea?

    /// Called when the user clicks a link.
    public var onOpenURL: ((URL) -> Void)?

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
        onOpenURL = nil
        NSCursor.arrow.set()
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

        // Update tracking area for cursor changes
        updateTrackingArea()
    }

    // MARK: - Link Hit Testing

    /// Convert a view-space point to CTFrame coordinate space (bottom-up).
    private func ctFramePoint(from viewPoint: CGPoint) -> CGPoint {
        CGPoint(x: viewPoint.x, y: view.bounds.height - viewPoint.y)
    }

    private func linkAtPoint(_ viewPoint: CGPoint) -> URL? {
        guard let ctFrame = drawingLayer?.ctFrame,
              let attrString = currentAttrString
        else { return nil }
        let pt = ctFramePoint(from: viewPoint)
        guard let index = characterIndex(in: ctFrame, at: pt) else { return nil }
        return linkURL(in: attrString, at: index)
    }

    // MARK: - Mouse Events

    public override func mouseDown(with event: NSEvent) {
        let point = view.convert(event.locationInWindow, from: nil)
        if let url = linkAtPoint(point) {
            onOpenURL?(url)
        } else {
            super.mouseDown(with: event)
        }
    }

    public override func mouseMoved(with event: NSEvent) {
        let point = view.convert(event.locationInWindow, from: nil)
        if linkAtPoint(point) != nil {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    // MARK: - Tracking Area

    private func updateTrackingArea() {
        if let existing = trackingArea {
            view.removeTrackingArea(existing)
        }
        let ta = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseMoved, .activeInKeyWindow, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(ta)
        trackingArea = ta
    }

    public override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
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
    private var tapRecognizer: UITapGestureRecognizer?

    /// Called when the user taps a link.
    public var onOpenURL: ((URL) -> Void)?

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
        ensureTapRecognizer()
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        drawingLayer?.reset()
        decorationLayer?.reset()
        currentAttrString = nil
        currentBlock = nil
        onOpenURL = nil
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

    // MARK: - Link Hit Testing

    /// Convert a view-space point to CTFrame coordinate space (bottom-up).
    private func ctFramePoint(from viewPoint: CGPoint) -> CGPoint {
        CGPoint(x: viewPoint.x, y: contentView.bounds.height - viewPoint.y)
    }

    private func linkAtPoint(_ viewPoint: CGPoint) -> URL? {
        guard let ctFrame = drawingLayer?.ctFrame,
              let attrString = currentAttrString
        else { return nil }
        let pt = ctFramePoint(from: viewPoint)
        guard let index = characterIndex(in: ctFrame, at: pt) else { return nil }
        return linkURL(in: attrString, at: index)
    }

    // MARK: - Tap Handling

    private func ensureTapRecognizer() {
        guard tapRecognizer == nil else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        contentView.addGestureRecognizer(tap)
        tapRecognizer = tap
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: contentView)
        if let url = linkAtPoint(point) {
            onOpenURL?(url)
        }
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
