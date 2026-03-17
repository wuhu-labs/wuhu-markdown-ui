import SwiftUI

/// SwiftUI wrapper around `DocCollectionViewController`.
///
/// ```swift
/// // Basic usage:
/// DocView(document: myDocument)
///
/// // With external custom block views:
/// DocView(document: myDocument) { block in
///     guard case .custom(let tag) = block.kind else { return nil }
///     switch tag {
///     case "kanban":
///         return AnyView(KanbanBoardView(block: block))
///     default:
///         return nil  // fall back to built-in views
///     }
/// }
///
/// // With scroll tracking for streaming:
/// DocView(document: streamingDocument)
///     .trackingTail(isStreaming)
/// ```

#if canImport(AppKit)
import AppKit

public struct DocView: NSViewControllerRepresentable {
    public var document: Document
    public var customBlockView: (@MainActor (FlatBlock) -> AnyView?)?

    var scrollTracking: ScrollTracking = .manual

    @Environment(\.openURL) private var openURL

    public init(
        document: Document,
        customBlockView: (@MainActor (FlatBlock) -> AnyView?)? = nil
    ) {
        self.document = document
        self.customBlockView = customBlockView
    }

    /// Enable or disable auto-scroll-to-bottom behavior.
    public func trackingTail(_ enabled: Bool) -> DocView {
        var copy = self
        copy.scrollTracking = enabled ? .trackTail : .manual
        return copy
    }

    public func makeNSViewController(context: Context) -> DocCollectionViewController {
        let controller = DocCollectionViewController()
        controller.customBlockView = customBlockView
        controller.onOpenURL = { openURL($0) }
        controller.scrollTracking = scrollTracking
        return controller
    }

    public func updateNSViewController(
        _ controller: DocCollectionViewController,
        context: Context
    ) {
        controller.customBlockView = customBlockView
        controller.onOpenURL = { [openURL] in openURL($0) }
        controller.scrollTracking = scrollTracking
        controller.setDocument(document)
    }
}

#elseif canImport(UIKit)
import UIKit

public struct DocView: UIViewControllerRepresentable {
    public var document: Document
    public var customBlockView: (@MainActor (FlatBlock) -> AnyView?)?

    var scrollTracking: ScrollTracking = .manual

    @Environment(\.openURL) private var openURL

    public init(
        document: Document,
        customBlockView: (@MainActor (FlatBlock) -> AnyView?)? = nil
    ) {
        self.document = document
        self.customBlockView = customBlockView
    }

    /// Enable or disable auto-scroll-to-bottom behavior.
    public func trackingTail(_ enabled: Bool) -> DocView {
        var copy = self
        copy.scrollTracking = enabled ? .trackTail : .manual
        return copy
    }

    public func makeUIViewController(context: Context) -> DocCollectionViewController {
        let controller = DocCollectionViewController()
        controller.customBlockView = customBlockView
        controller.onOpenURL = { openURL($0) }
        controller.scrollTracking = scrollTracking
        return controller
    }

    public func updateUIViewController(
        _ controller: DocCollectionViewController,
        context: Context
    ) {
        controller.customBlockView = customBlockView
        controller.onOpenURL = { [openURL] in openURL($0) }
        controller.scrollTracking = scrollTracking
        controller.setDocument(document)
    }
}
#endif
