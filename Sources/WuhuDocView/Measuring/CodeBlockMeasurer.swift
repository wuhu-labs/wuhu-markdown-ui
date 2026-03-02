import CoreGraphics

/// Measures code blocks. Pure arithmetic from line count — no views.
public struct CodeBlockMeasurer: BlockMeasuring {
    public var lineHeight: CGFloat = 18
    public var verticalPadding: CGFloat = 24   // 12 top + 12 bottom
    public var maxHeight: CGFloat = 400        // scroll if taller

    public init() {}

    public func height(
        for block: FlatBlock, width: CGFloat, attributes: ResolvedAttributes
    ) -> CGFloat {
        guard case .codeBlock(let code) = block.content else { return 0 }
        let lineCount = code.code.components(separatedBy: "\n").count
        let naturalHeight = CGFloat(lineCount) * lineHeight + verticalPadding
        return min(naturalHeight, maxHeight)
    }
}
