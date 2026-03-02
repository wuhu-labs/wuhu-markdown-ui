import WuhuDocView

/// Sample documents built from our actual architecture discussion.
/// These serve as both test data and project documentation.
enum SampleData {

    // MARK: - Multi-Doc "Infinite View"

    static var infiniteDoc: Document {
        Document(sections: [
            architectureDecisionDoc,
            flatteningStrategyDoc,
            chatSessionDemo,
        ])
    }

    // MARK: - Architecture Decision Doc

    static var architectureDecisionDoc: DocSection {
        .doc(
            id: "doc-arch",
            title: "Architecture Decision: Unified Block IR",
            subtitle: "2025-01-17 · Accepted",
            blocks: [
                .heading(2, "Context"),
                .paragraph(
                    "The current chat UI in wuhu-app uses LazyVStack with MarkdownUI for rendering. "
                    + "This has several limitations: no control over inter-block margins, entire message "
                    + "re-renders on each streaming token, no path to cross-block text selection, and "
                    + "the rendering engine cannot be shared between chat and document views."
                ),
                .paragraph(
                    "We need a high-performance rendering layer that works for both chat messages "
                    + "and standalone documents."
                ),

                .heading(2, "Decision"),
                .paragraph(
                    "Build a unified block IR backed by NSCollectionView / UICollectionView with a "
                    + "custom layout. The IR flattens all content — markdown blocks, message headers, "
                    + "tool calls, user messages, document titles — into a single linear sequence of "
                    + "typed blocks."
                ),

                .heading(3, "Key Design Choices"),
                .paragraph("Messages as sections, blocks as cells.", indent: 1, decoration: .ordered(1)),
                .paragraph(
                    "Each message (or document) maps to a collection view section. Each block within "
                    + "that message is a cell.",
                    indent: 1
                ),
                .paragraph("Flat block list.", indent: 1, decoration: .ordered(2)),
                .paragraph(
                    "Nested markdown structures (block quotes, lists) are flattened into a linear "
                    + "sequence with indent and decoration metadata.",
                    indent: 1
                ),
                .paragraph("Custom layout, not compositional layout.", indent: 1, decoration: .ordered(3)),
                .paragraph(
                    "The layout computes all frames in prepare() using pre-measured block heights. "
                    + "No self-sizing negotiation. Margins are computed as a function of "
                    + "(prevBlockKind, nextBlockKind).",
                    indent: 1
                ),
                .paragraph("Core Text for text blocks.", indent: 1, decoration: .ordered(4)),
                .paragraph(
                    "Paragraphs, headings, list items, and blockquotes render via CTFrame in the "
                    + "cell's draw(rect:). No SwiftUI hosting overhead for the common path.",
                    indent: 1
                ),

                .thematicBreak(),

                .heading(2, "Block Type Taxonomy"),
                .table(
                    headers: ["Cell Type", "Rendering", "Notes"],
                    rows: [
                        ["TextCell", "Core Text CTFrame", "Paragraphs, headings, list items, blockquotes"],
                        ["CodeBlockCell", "NSTextView (scrollable)", "Syntax highlighted, horizontally scrollable"],
                        ["TableCell", "Custom grid view", "Monolithic re-render"],
                        ["ImageCell", "AsyncImage / native", "Loaded from blob URIs"],
                        ["CustomBlockCell", "Per-tag view factory", "Message headers, tool calls, doc headers"],
                    ]
                ),

                .heading(2, "Consequences"),
                .paragraph("The rendering engine is reusable across chat, docs, and infinite-doc views.", indent: 1, decoration: .bullet),
                .paragraph("Streaming invalidation is surgical — one cell, not one message.", indent: 1, decoration: .bullet),
                .paragraph("Full control over margins, spacing, and visual treatment per block type.", indent: 1, decoration: .bullet),
                .paragraph("Cross-block text selection becomes feasible as future work.", indent: 1, decoration: .bullet),
                .paragraph("Higher implementation complexity vs. SwiftUI-only approach.", indent: 1, decoration: .bullet),
            ]
        )
    }

    // MARK: - Flattening Strategy Doc

    static var flatteningStrategyDoc: DocSection {
        .doc(
            id: "doc-flatten",
            title: "Block Flattening Strategy",
            subtitle: "2025-01-17",
            blocks: [
                .heading(2, "The Problem"),
                .paragraph(
                    "UICollectionView is a flat list of cells. Markdown has nested structures: "
                    + "block quotes containing lists containing paragraphs. We need a flattening "
                    + "strategy that preserves visual fidelity while producing a linear cell sequence."
                ),

                .heading(2, "Approach"),
                .paragraph(
                    "Every node in the markdown AST becomes a FlatBlock carrying an indent level "
                    + "(controls leading offset) and an optional decoration (gutter decoration like "
                    + "quote bars, bullets, or numbers)."
                ),

                .heading(3, "Simple List Example"),
                .paragraph("Item one — the first thing to consider", indent: 1, decoration: .bullet),
                .paragraph("Item two — building on the first point", indent: 1, decoration: .bullet),
                .paragraph("Nested item — a refinement", indent: 2, decoration: .bullet),
                .paragraph("Item three — the conclusion", indent: 1, decoration: .bullet),

                .heading(3, "Block Quote with List"),
                .paragraph(
                    "Here is a quoted section with embedded reasoning about the architecture.",
                    indent: 1,
                    decoration: .quoteBar
                ),
                .paragraph("First point — collection view handles thousands of sections", indent: 1, decoration: .quoteBarAndBullet),
                .paragraph("Second point — only visible cells are instantiated", indent: 1, decoration: .quoteBarAndBullet),
                .paragraph(
                    "And the conclusion: sections are just index-path metadata, not views.",
                    indent: 1,
                    decoration: .quoteBar
                ),

                .heading(3, "Irreducible Blocks"),
                .paragraph(
                    "Code blocks and tables cannot be meaningfully flattened further. They become "
                    + "single cells regardless of nesting depth, carrying the accumulated indent."
                ),
                .codeBlock(language: "swift", """
                struct FlatBlock: Hashable, Identifiable {
                    var id: BlockID
                    var content: BlockContent
                    var indent: Int
                    var decoration: Decoration?
                }
                """),
                .paragraph(
                    "The flattener walks the AST depth-first. Each leaf block-level node emits a "
                    + "FlatBlock. Container nodes (block quotes, list items) increment the indent "
                    + "counter and set the decoration for their first child."
                ),
            ]
        )
    }

    // MARK: - Chat Session Demo

    /// Demonstrates that the same IR renders a chat conversation: each message
    /// is a section, with message headers and tool calls as custom blocks.
    static var chatSessionDemo: DocSection {
        // We'll model this as a "meta-document" that contains the chat,
        // to show it in the infinite-doc view. In a real chat view, each
        // message would be its own section.
        .doc(
            id: "doc-chat-demo",
            title: "Chat Session: Auth Token Fix",
            subtitle: "Demonstrating chat as blocks",
            blocks: [
                // User message (inline, since we're in a single doc section for the demo)
                .paragraph("minsheng:", indent: 0, decoration: .quoteBar),
                .paragraph(
                    "The auth token refresh is failing silently. When the access token expires, "
                    + "the refresh request returns 401 but we're not handling it. Can you investigate?",
                    indent: 0,
                    decoration: .quoteBar
                ),

                .thematicBreak(),

                .paragraph("Agent:"),
                .paragraph(
                    "I'll look into the auth token refresh logic. Let me start by reading the "
                    + "current implementation."
                ),
                .toolCall(name: "read_file", args: "Sources/WuhuClient/Auth.swift"),
                .paragraph(
                    "I see the issue — refreshToken() doesn't check the HTTP status before decoding. "
                    + "A 401 body isn't a valid Token, so decode throws, but the error gets swallowed."
                ),
                .toolCall(name: "bash", args: "grep -rn \"refreshToken\" Sources/"),

                .thematicBreak(),

                .paragraph("anna:", indent: 0, decoration: .quoteBar),
                .paragraph(
                    "Yeah I hit this too. The retry also doesn't distinguish between \"original 401\" "
                    + "vs \"refresh itself got 401\" — if the refresh token is expired we'd loop.",
                    indent: 0,
                    decoration: .quoteBar
                ),

                .thematicBreak(),

                .paragraph("Agent:"),
                .paragraph("The fix is threefold:"),
                .paragraph("Add status code checking in refreshToken()", indent: 1, decoration: .ordered(1)),
                .paragraph("Throw AuthError.refreshTokenExpired when refresh endpoint returns 401", indent: 1, decoration: .ordered(2)),
                .paragraph("In executeWithRetry, catch that specific error and propagate instead of retrying", indent: 1, decoration: .ordered(3)),

                .codeBlock(language: "swift", """
                func refreshToken() async throws -> Token {
                    let response = try await httpClient.post("/auth/refresh", body: refreshBody)
                    guard response.status == .ok else {
                        if response.status == .unauthorized {
                            throw AuthError.refreshTokenExpired
                        }
                        throw AuthError.refreshFailed(response.status)
                    }
                    return try decoder.decode(Token.self, from: response.body)
                }
                """),
                .toolCall(name: "edit_file", args: "Sources/WuhuClient/Auth.swift"),
                .toolCall(name: "bash", args: "swift test --filter AuthTests"),
                .paragraph("All 4 auth tests pass. The fix handles network errors during refresh as well."),
            ]
        )
    }
}
