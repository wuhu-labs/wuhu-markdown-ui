import CoreGraphics
import SwiftUI

/// Dispatches measurement to the appropriate `BlockMeasuring` conformer based
/// on block content. Also owns geometry concerns (indent, content insets).
///
/// Replaces the monolithic `BlockMeasurer` struct. Each content type has its
/// own measurer which can be swapped or overridden.
@MainActor
public struct BlockMeasurerRegistry {

    public var indentWidth: CGFloat
    public var contentInsets: CGFloat

    // MARK: - Measurers (one per content kind)

    public var textMeasurer: any BlockMeasuring = TextBlockMeasurer()
    public var codeMeasurer: any BlockMeasuring = CodeBlockMeasurer()
    public var tableMeasurer: any ViewBasedBlockMeasuring = TableBlockMeasurer()
    public var thematicBreakMeasurer: any BlockMeasuring = ConstantHeightMeasurer(9)
    public var imageMeasurer: any BlockMeasuring = ConstantHeightMeasurer(200) // placeholder
    public var customMeasurer: any ViewBasedBlockMeasuring = CustomBlockMeasurer()

    public init(indentWidth: CGFloat = 24, contentInsets: CGFloat = 16) {
        self.indentWidth = indentWidth
        self.contentInsets = contentInsets
    }

    // MARK: - Measurement

    /// Measure the height of a block given the total available width of the
    /// collection view.
    public func measureHeight(
        of block: FlatBlock,
        availableWidth: CGFloat,
        resolvedAttributes: ResolvedAttributes
    ) -> CGFloat {
        let width = contentWidth(for: block, availableWidth: availableWidth)
        return measurer(for: block).height(for: block, width: width, attributes: resolvedAttributes)
    }

    // MARK: - View Access

    /// Return the SwiftUI view for a block, if the block's measurer is
    /// view-based. Used by the collection view controller to configure
    /// `HostedSwiftUICell` with the exact same view used for measurement.
    ///
    /// Returns `nil` for blocks measured without views (text, code, etc.).
    public func swiftUIView(for block: FlatBlock) -> AnyView? {
        let m = measurer(for: block)
        if let viewBased = m as? (any ViewBasedBlockMeasuring) {
            return viewBased.view(for: block)
        }
        return nil
    }

    // MARK: - Geometry

    /// The width available for content after subtracting indentation and insets.
    public func contentWidth(for block: FlatBlock, availableWidth: CGFloat) -> CGFloat {
        let indentOffset = CGFloat(block.indent) * indentWidth
        return max(availableWidth - indentOffset - contentInsets * 2, 40)
    }

    /// The leading X offset for a block's content area.
    public func leadingOffset(for block: FlatBlock) -> CGFloat {
        contentInsets + CGFloat(block.indent) * indentWidth
    }

    // MARK: - Dispatch

    private func measurer(for block: FlatBlock) -> any BlockMeasuring {
        switch block.content {
        case .text:           textMeasurer
        case .codeBlock:      codeMeasurer
        case .table:          tableMeasurer
        case .thematicBreak:  thematicBreakMeasurer
        case .image:          imageMeasurer
        case .custom:         customMeasurer
        }
    }
}
