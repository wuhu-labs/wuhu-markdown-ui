import CoreGraphics
import CoreText
import Foundation

/// Measures text blocks (headings, paragraphs, blockquotes) using Core Text.
/// Pure computation — no views instantiated.
public struct TextBlockMeasurer: BlockMeasuring {
    public init() {}

    public func height(
        for block: FlatBlock, width: CGFloat, attributes: ResolvedAttributes
    ) -> CGFloat {
        guard case .text(let inline) = block.content else { return 0 }

        let nsAttrString = attributes.applyStyle(to: inline.attributedString, kind: block.kind)
        let framesetter = CTFramesetterCreateWithAttributedString(nsAttrString)
        var fitRange = CFRange(location: 0, length: 0)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: nsAttrString.length),
            nil,
            CGSize(width: width, height: .greatestFiniteMagnitude),
            &fitRange
        )

        let verticalPadding: CGFloat = switch block.kind {
        case .heading(let level) where level <= 2: 8
        case .heading: 4
        default: 0
        }

        return ceil(suggestedSize.height) + verticalPadding
    }
}
