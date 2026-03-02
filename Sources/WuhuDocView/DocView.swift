import SwiftUI

/// SwiftUI wrapper around `DocCollectionViewController`.
///
/// ```swift
/// DocView(document: myDocument)
/// ```

#if canImport(AppKit)
import AppKit

public struct DocView: NSViewControllerRepresentable {
    public var document: Document

    public init(document: Document) {
        self.document = document
    }

    public func makeNSViewController(context: Context) -> DocCollectionViewController {
        DocCollectionViewController()
    }

    public func updateNSViewController(
        _ controller: DocCollectionViewController,
        context: Context
    ) {
        controller.setDocument(document)
    }
}

#elseif canImport(UIKit)
import UIKit

public struct DocView: UIViewControllerRepresentable {
    public var document: Document

    public init(document: Document) {
        self.document = document
    }

    public func makeUIViewController(context: Context) -> DocCollectionViewController {
        DocCollectionViewController()
    }

    public func updateUIViewController(
        _ controller: DocCollectionViewController,
        context: Context
    ) {
        controller.setDocument(document)
    }
}
#endif
