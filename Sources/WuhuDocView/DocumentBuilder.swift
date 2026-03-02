/// Convenience API for building `Document` instances from structured data.
/// This is what consumers use to feed the doc view.

// MARK: - Section Builders

extension DocSection {

    /// Build a document section with a doc header and a sequence of content
    /// blocks.
    public static func doc(
        id: String,
        title: String,
        subtitle: String? = nil,
        blocks: [FlatBlock]
    ) -> DocSection {
        var allBlocks: [FlatBlock] = []

        // Doc header as a custom block
        var headerFields: [String: String] = ["title": title]
        if let subtitle { headerFields["subtitle"] = subtitle }

        let headerBlock = FlatBlock(
            id: BlockID(sectionID: id, index: 0, kind: .custom("docHeader")),
            content: .custom(CustomBlockContent(headerFields))
        )
        allBlocks.append(headerBlock)

        // Re-index content blocks to follow the header
        for (i, var block) in blocks.enumerated() {
            block.id = BlockID(
                sectionID: id,
                index: i + 1,
                kind: block.kind
            )
            allBlocks.append(block)
        }

        return DocSection(id: id, blocks: allBlocks)
    }

    /// Build a chat message section.
    public static func message(
        id: String,
        role: String,
        author: String? = nil,
        timestamp: String = "",
        blocks: [FlatBlock]
    ) -> DocSection {
        var allBlocks: [FlatBlock] = []

        // Message header
        var headerFields: [String: String] = ["role": role]
        if let author { headerFields["author"] = author }
        headerFields["timestamp"] = timestamp

        let headerBlock = FlatBlock(
            id: BlockID(sectionID: id, index: 0, kind: .custom("messageHeader")),
            content: .custom(CustomBlockContent(headerFields))
        )
        allBlocks.append(headerBlock)

        for (i, var block) in blocks.enumerated() {
            block.id = BlockID(sectionID: id, index: i + 1, kind: block.kind)
            allBlocks.append(block)
        }

        return DocSection(id: id, blocks: allBlocks)
    }
}

// MARK: - Block Builders

/// Convenience functions for creating blocks. The `sectionID` and `index`
/// in the BlockID are placeholders — they get overwritten by the section
/// builder.
extension FlatBlock {

    /// A heading block.
    public static func heading(_ level: Int, _ text: String) -> FlatBlock {
        FlatBlock(
            id: BlockID(sectionID: "_", index: 0, kind: .heading(level: level)),
            content: .text(InlineContent(plain: text))
        )
    }

    /// A paragraph block.
    public static func paragraph(_ text: String) -> FlatBlock {
        FlatBlock(
            id: BlockID(sectionID: "_", index: 0, kind: .paragraph),
            content: .text(InlineContent(plain: text))
        )
    }

    /// A paragraph with indent and optional decoration (for flattened lists /
    /// blockquotes).
    public static func paragraph(
        _ text: String,
        indent: Int,
        decoration: Decoration? = nil
    ) -> FlatBlock {
        FlatBlock(
            id: BlockID(sectionID: "_", index: 0, kind: .paragraph),
            content: .text(InlineContent(plain: text)),
            indent: indent,
            decoration: decoration
        )
    }

    /// A code block.
    public static func codeBlock(language: String? = nil, _ code: String) -> FlatBlock {
        FlatBlock(
            id: BlockID(sectionID: "_", index: 0, kind: .codeBlock),
            content: .codeBlock(CodeBlockContent(language: language, code: code))
        )
    }

    /// A table block.
    public static func table(headers: [String], rows: [[String]]) -> FlatBlock {
        FlatBlock(
            id: BlockID(sectionID: "_", index: 0, kind: .table),
            content: .table(TableContent(headers: headers, rows: rows))
        )
    }

    /// A thematic break (horizontal rule).
    public static func thematicBreak() -> FlatBlock {
        FlatBlock(
            id: BlockID(sectionID: "_", index: 0, kind: .thematicBreak),
            content: .thematicBreak
        )
    }

    /// A tool call block (custom).
    public static func toolCall(name: String, args: String = "") -> FlatBlock {
        FlatBlock(
            id: BlockID(sectionID: "_", index: 0, kind: .custom("toolCall")),
            content: .custom(CustomBlockContent([
                "name": name,
                "args": args,
            ]))
        )
    }
}
