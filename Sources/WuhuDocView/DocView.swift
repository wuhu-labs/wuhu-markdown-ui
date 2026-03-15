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
/// ```

#if canImport(AppKit)
import AppKit

public struct DocView: NSViewControllerRepresentable {
    public var document: Document
    public var customBlockView: (@MainActor (FlatBlock) -> AnyView?)?

    @Environment(\.openURL) private var openURL

    public init(
        document: Document,
        customBlockView: (@MainActor (FlatBlock) -> AnyView?)? = nil
    ) {
        self.document = document
        self.customBlockView = customBlockView
    }

    public func makeNSViewController(context: Context) -> DocCollectionViewController {
        let controller = DocCollectionViewController()
        controller.customBlockView = customBlockView
        controller.onOpenURL = { openURL($0) }
        return controller
    }

    public func updateNSViewController(
        _ controller: DocCollectionViewController,
        context: Context
    ) {
        controller.customBlockView = customBlockView
        controller.onOpenURL = { [openURL] in openURL($0) }
        controller.setDocument(document)
    }
}

#elseif canImport(UIKit)
import UIKit

public struct DocView: UIViewControllerRepresentable {
    public var document: Document
    public var customBlockView: (@MainActor (FlatBlock) -> AnyView?)?

    @Environment(\.openURL) private var openURL

    public init(
        document: Document,
        customBlockView: (@MainActor (FlatBlock) -> AnyView?)? = nil
    ) {
        self.document = document
        self.customBlockView = customBlockView
    }

    public func makeUIViewController(context: Context) -> DocCollectionViewController {
        let controller = DocCollectionViewController()
        controller.customBlockView = customBlockView
        controller.onOpenURL = { openURL($0) }
        return controller
    }

    public func updateUIViewController(
        _ controller: DocCollectionViewController,
        context: Context
    ) {
        controller.customBlockView = customBlockView
        controller.onOpenURL = { [openURL] in openURL($0) }
        controller.setDocument(document)
    }
}
#endif
