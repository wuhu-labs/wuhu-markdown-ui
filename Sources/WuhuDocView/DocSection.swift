/// A section in the document view. Maps to one collection view section.
///
/// A section can represent a chat message, a standalone document, a daily
/// journal entry in an infinite-doc view, etc. The document view doesn't
/// care about the semantic meaning — it just renders the blocks.
public struct DocSection: Identifiable, Hashable, Sendable {
    public var id: String
    public var blocks: [FlatBlock]

    public init(id: String, blocks: [FlatBlock]) {
        self.id = id
        self.blocks = blocks
    }
}

// MARK: - Document

/// A complete document: an ordered list of sections that the collection view
/// renders top-to-bottom. For a chat view each section is a message. For a
/// multi-doc "infinite view" each section is a document.
public struct Document: Hashable, Sendable {
    public var sections: [DocSection]

    public init(sections: [DocSection]) {
        self.sections = sections
    }

    /// Total number of blocks across all sections.
    public var blockCount: Int {
        sections.reduce(0) { $0 + $1.blocks.count }
    }
}
