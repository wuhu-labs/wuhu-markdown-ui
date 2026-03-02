import QuartzCore

// MARK: - macOS

#if canImport(AppKit)
import AppKit

/// Renders a horizontal rule via a `CALayer`. No drawing code — just a
/// sublayer with a background color, positioned in `viewDidLayout`.
public final class ThematicBreakCell: NSCollectionViewItem {
    public static let identifier = NSUserInterfaceItemIdentifier("ThematicBreakCell")

    private var lineLayer: CALayer?

    public override func loadView() { self.view = LayerHostView() }

    public override func viewDidLayout() {
        super.viewDidLayout()
        let line = ensureLineLayer()
        line.frame = CGRect(
            x: 0, y: view.bounds.midY - 0.5,
            width: view.bounds.width, height: 1
        )
    }

    private func ensureLineLayer() -> CALayer {
        if let l = lineLayer { return l }
        let l = CALayer()
        l.backgroundColor = NSColor.separatorColor.cgColor
        view.layer?.addSublayer(l)
        lineLayer = l
        return l
    }
}

// MARK: - iOS

#elseif canImport(UIKit)
import UIKit

public final class ThematicBreakCell: UICollectionViewCell {
    public static let reuseIdentifier = "ThematicBreakCell"

    private var lineLayer: CALayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let l = CALayer()
        l.backgroundColor = UIColor.separator.cgColor
        contentView.layer.addSublayer(l)
        lineLayer = l
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override func layoutSubviews() {
        super.layoutSubviews()
        lineLayer?.frame = CGRect(
            x: 0, y: contentView.bounds.midY - 0.5,
            width: contentView.bounds.width, height: 1
        )
    }
}
#endif
