import Foundation

/// Unique identity for a block within the document view.
///
/// Composed of the section (document/message) ID, the block's index within
/// that section, and the block's kind. The kind component ensures that if the
/// parser reinterprets a paragraph as a heading, it's treated as a new block
/// rather than a mutation of the old one.
public struct BlockID: Hashable, Sendable {
    public var sectionID: String
    public var index: Int
    public var kind: BlockKind

    public init(sectionID: String, index: Int, kind: BlockKind) {
        self.sectionID = sectionID
        self.index = index
        self.kind = kind
    }
}

// MARK: - BlockKind

/// The type of a flattened block. Determines which cell type renders it and
/// how the layout computes margins.
public enum BlockKind: Hashable, Sendable {
    // Markdown leaf blocks — rendered via Core Text
    case heading(level: Int)
    case paragraph
    case blockquote       // unused as a standalone kind after flattening,
                          // but reserved for blockquote-only paragraphs
    case thematicBreak

    // Irreducible blocks — rendered via hosted views
    case codeBlock
    case table

    // Media
    case image

    // Custom / domain-specific blocks
    case custom(String)   // extensible tag, e.g. "messageHeader", "toolCall",
                          // "userBubble", "docHeader"
}

// MARK: - Decoration

/// Gutter decoration drawn in the indent area to the left of a block's
/// content. Produced by the flattener when walking nested list / blockquote
/// structures.
public enum Decoration: Hashable, Sendable {
    case bullet
    case ordered(Int)
    case quoteBar
    case quoteBarAndBullet
    case quoteBarAndOrdered(Int)
}

// MARK: - InlineContent

/// The rendered inline content for a text block. Currently wraps an
/// `NSAttributedString` produced from parsed markdown inline nodes.
/// In the future this may carry a structured inline tree for richer
/// hit-testing and accessibility.
public struct InlineContent: Hashable, Sendable {
    public var attributedString: AttributedString

    public init(_ attributedString: AttributedString) {
        self.attributedString = attributedString
    }

    public init(plain string: String) {
        self.attributedString = AttributedString(string)
    }
}

// MARK: - CodeBlockContent

public struct CodeBlockContent: Hashable, Sendable {
    public var language: String?
    public var code: String

    public init(language: String? = nil, code: String) {
        self.language = language
        self.code = code
    }
}

// MARK: - TableContent

public struct TableContent: Hashable, Sendable {
    public var headers: [String]
    public var rows: [[String]]

    public init(headers: [String], rows: [[String]]) {
        self.headers = headers
        self.rows = rows
    }
}

// MARK: - ImageContent

public struct ImageContent: Hashable, Sendable {
    public var url: String
    public var altText: String?

    public init(url: String, altText: String? = nil) {
        self.url = url
        self.altText = altText
    }
}

// MARK: - CustomBlockContent

/// Opaque payload for domain-specific blocks. The renderer looks up a
/// registered view factory by the block's custom tag.
public struct CustomBlockContent: Hashable, Sendable {
    /// Arbitrary key-value data for the custom block.
    public var fields: [String: String]

    public init(_ fields: [String: String] = [:]) {
        self.fields = fields
    }
}

// MARK: - BlockContent

/// The payload of a `FlatBlock`. Determines what gets rendered in the cell.
public enum BlockContent: Hashable, Sendable {
    case text(InlineContent)
    case codeBlock(CodeBlockContent)
    case table(TableContent)
    case image(ImageContent)
    case thematicBreak
    case custom(CustomBlockContent)
}

// MARK: - FlatBlock

/// A single block in the flattened IR. This is the atom of the document view:
/// one `FlatBlock` = one collection view cell.
public struct FlatBlock: Hashable, Identifiable, Sendable {
    public var id: BlockID
    public var content: BlockContent
    public var indent: Int
    public var decoration: Decoration?

    public init(
        id: BlockID,
        content: BlockContent,
        indent: Int = 0,
        decoration: Decoration? = nil
    ) {
        self.id = id
        self.content = content
        self.indent = indent
        self.decoration = decoration
    }

    public var kind: BlockKind { id.kind }
}
