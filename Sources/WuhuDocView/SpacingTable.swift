import CoreGraphics

/// Computes vertical spacing between adjacent blocks based on their types.
///
/// The layout reads this during `prepare()` to determine the Y offset between
/// consecutive cells. This is where the "fine-grained margin story" lives —
/// every block-type pair can have custom spacing.
public struct SpacingTable: Sendable {

    /// The function that computes spacing given previous and next block kinds.
    /// Receives `nil` for `prev` on the first block in a section, and `nil`
    /// for `next` on the last block.
    public var spacing: @Sendable (BlockKind?, BlockKind?) -> CGFloat

    public init(spacing: @escaping @Sendable (BlockKind?, BlockKind?) -> CGFloat) {
        self.spacing = spacing
    }
}

// MARK: - Default Spacing

extension SpacingTable {

    /// A reasonable default spacing table for document / chat rendering.
    public static let `default` = SpacingTable { prev, next in
        guard let prev, let next else { return 0 }

        switch (prev, next) {
        // After headings: tight coupling to content below
        case (.heading(let level), _) where level <= 2:
            return 10
        case (.heading, _):
            return 8

        // Before headings: generous breathing room
        case (_, .heading(let level)) where level <= 2:
            return 28
        case (_, .heading):
            return 20

        // Code blocks get extra space on both sides
        case (.codeBlock, _):
            return 16
        case (_, .codeBlock):
            return 16

        // Tables also get extra space
        case (.table, _):
            return 16
        case (_, .table):
            return 16

        // Thematic breaks
        case (.thematicBreak, _):
            return 16
        case (_, .thematicBreak):
            return 16

        // Custom blocks (message headers, tool calls, etc.)
        case (.custom, _):
            return 8
        case (_, .custom):
            return 8

        // Paragraph to paragraph
        case (.paragraph, .paragraph):
            return 10

        // Default
        default:
            return 10
        }
    }

    /// Spacing between sections (e.g., between messages or between documents).
    public var sectionSpacing: CGFloat { 32 }
}
