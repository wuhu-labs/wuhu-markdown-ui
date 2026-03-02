import CoreGraphics
import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - BlockMeasuring

/// A type that can compute the height of a block given the available width.
///
/// Conformers that can compute height purely from data (Core Text, arithmetic,
/// constants) conform directly. Conformers that need a SwiftUI view to measure
/// conform to `ViewBasedBlockMeasuring` instead, which provides a default
/// implementation via hosting-view measurement.
@MainActor
public protocol BlockMeasuring {
    /// Compute the height for the given block at the given content width.
    func height(for block: FlatBlock, width: CGFloat, attributes: ResolvedAttributes) -> CGFloat
}

// MARK: - ViewBasedBlockMeasuring

/// A measurer that provides a SwiftUI view for both measurement and rendering.
///
/// The `view(for:)` method returns the same view used in the cell. The default
/// `height(for:width:attributes:)` implementation instantiates a temporary
/// hosting view, constrains it to the given width, and returns the fitted
/// height. The hosting view is discarded after measurement — no persistent
/// allocation.
@MainActor
public protocol ViewBasedBlockMeasuring: BlockMeasuring {
    /// The SwiftUI view for this block. Used for both measurement and cell
    /// content — single source of truth.
    func view(for block: FlatBlock) -> AnyView
}

extension ViewBasedBlockMeasuring {
    public func height(
        for block: FlatBlock, width: CGFloat, attributes: ResolvedAttributes
    ) -> CGFloat {
        let swiftUIView = view(for: block)
        return Self.measureHostingView(swiftUIView, width: width)
    }

    /// Instantiate a temporary hosting view, measure, discard.
    public static func measureHostingView(_ swiftUIView: AnyView, width: CGFloat) -> CGFloat {
        #if canImport(AppKit)
        let hosting = NSHostingView(rootView: swiftUIView)
        hosting.frame.size.width = width
        hosting.layoutSubtreeIfNeeded()
        return ceil(hosting.fittingSize.height)
        #elseif canImport(UIKit)
        let hc = UIHostingController(rootView: swiftUIView)
        let size = hc.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        return ceil(size.height)
        #endif
    }
}
