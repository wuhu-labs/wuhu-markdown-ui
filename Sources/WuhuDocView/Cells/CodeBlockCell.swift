// MARK: - macOS

#if canImport(AppKit)
import AppKit

public final class CodeBlockCell: NSCollectionViewItem {
    public static let identifier = NSUserInterfaceItemIdentifier("CodeBlockCell")

    private lazy var scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = true
        sv.autohidesScrollers = true
        sv.borderType = .noBorder
        sv.drawsBackground = true
        sv.wantsLayer = true
        sv.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.5)
        sv.documentView = textView
        return sv
    }()

    private lazy var textView: NSTextView = {
        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isRichText = false
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.textColor = .labelColor
        tv.backgroundColor = .clear
        tv.textContainerInset = NSSize(width: 12, height: 12)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = true
        tv.textContainer?.widthTracksTextView = false
        tv.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        tv.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        return tv
    }()

    public override func loadView() {
        let v = LayerHostView()
        v.layer?.cornerRadius = 6
        v.layer?.backgroundColor = NSColor.windowBackgroundColor
            .withAlphaComponent(0.5).cgColor
        self.view = v
    }

    public override func viewDidLayout() {
        super.viewDidLayout()
        scrollView.frame = view.bounds
    }

    public func configure(with code: CodeBlockContent) {
        if scrollView.superview == nil {
            view.addSubview(scrollView)
            scrollView.frame = view.bounds
        }
        textView.string = code.code
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        textView.string = ""
    }
}

// MARK: - iOS

#elseif canImport(UIKit)
import UIKit

public final class CodeBlockCell: UICollectionViewCell {
    public static let reuseIdentifier = "CodeBlockCell"

    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.textColor = .label
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.showsHorizontalScrollIndicator = true
        return tv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 6
        contentView.clipsToBounds = true
        contentView.addSubview(textView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = contentView.bounds
    }

    public func configure(with code: CodeBlockContent) {
        textView.text = code.code
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        textView.text = ""
    }
}
#endif
