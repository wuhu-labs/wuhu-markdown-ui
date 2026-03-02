import CoreGraphics

/// Returns a fixed height regardless of block content. Used for thematic
/// breaks and any other block with a known constant height.
public struct ConstantHeightMeasurer: BlockMeasuring {
    public let fixedHeight: CGFloat

    public init(_ height: CGFloat) {
        self.fixedHeight = height
    }

    public func height(
        for block: FlatBlock, width: CGFloat, attributes: ResolvedAttributes
    ) -> CGFloat {
        fixedHeight
    }
}
