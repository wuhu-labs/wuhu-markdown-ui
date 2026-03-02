import SwiftUI

// MARK: - macOS

#if canImport(AppKit)
import AppKit

/// A generic cell that hosts any SwiftUI view via `NSHostingView`.
/// Used for tables, custom blocks, and anything rendered with SwiftUI.
public final class HostedSwiftUICell: NSCollectionViewItem {
    public static let identifier = NSUserInterfaceItemIdentifier("HostedSwiftUICell")

    private var hostingView: NSHostingView<AnyView>?

    public override func loadView() { self.view = LayerHostView() }

    public func configure(with swiftUIView: AnyView) {
        if let hosting = hostingView {
            hosting.rootView = swiftUIView
        } else {
            let hosting = NSHostingView(rootView: swiftUIView)
            hosting.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.topAnchor.constraint(equalTo: view.topAnchor),
                hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            hostingView = hosting
        }
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        hostingView?.removeFromSuperview()
        hostingView = nil
    }
}

// MARK: - iOS

#elseif canImport(UIKit)
import UIKit

/// A generic cell that hosts any SwiftUI view via `UIHostingController`.
public final class HostedSwiftUICell: UICollectionViewCell {
    public static let reuseIdentifier = "HostedSwiftUICell"

    private var hostController: UIHostingController<AnyView>?

    public func configure(with swiftUIView: AnyView, parentController: UIViewController) {
        if let hc = hostController {
            hc.rootView = swiftUIView
        } else {
            let hc = UIHostingController(rootView: swiftUIView)
            hc.view.backgroundColor = .clear
            hc.view.translatesAutoresizingMaskIntoConstraints = false
            parentController.addChild(hc)
            contentView.addSubview(hc.view)
            NSLayoutConstraint.activate([
                hc.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hc.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hc.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hc.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
            hc.didMove(toParent: parentController)
            hostController = hc
        }
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        hostController?.willMove(toParent: nil)
        hostController?.view.removeFromSuperview()
        hostController?.removeFromParent()
        hostController = nil
    }
}
#endif
