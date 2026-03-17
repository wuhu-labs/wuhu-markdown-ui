import SwiftUI
import WuhuDocView

/// Simulates LLM streaming by feeding tokens into a `DocView` with
/// `trackingTail` enabled. Demonstrates that the content-aware diff
/// correctly updates only the changing block while the height cache
/// keeps unchanged blocks cheap.
struct StreamingDemoView: View {
    @State private var streamer = StreamSimulator()

    var body: some View {
        VStack(spacing: 0) {
            DocView(document: streamer.document)
                .trackingTail(streamer.isStreaming)

            Divider()

            HStack(spacing: 12) {
                Button(streamer.isStreaming ? "Stop" : "Start Streaming") {
                    if streamer.isStreaming {
                        streamer.stop()
                    } else {
                        streamer.start()
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button("Reset") {
                    streamer.reset()
                }
                .disabled(streamer.isStreaming)

                Spacer()

                Text("\(streamer.document.blockCount) blocks")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
    }
}

// MARK: - Stream Simulator

/// Feeds pre-baked token chunks into a `Document` at a timer-driven pace,
/// simulating what `wuhu-app` does during LLM streaming.
@Observable
@MainActor
final class StreamSimulator {
    private(set) var document: Document = Document(sections: [])
    private(set) var isStreaming: Bool = false

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var tokenIndex: Int = 0
    @ObservationIgnored private var snapshots: [() -> Document] = []

    init() {
        self.snapshots = StreamSimulator.buildSnapshots()
    }

    /// The full conversation to stream, broken into incremental snapshots.
    /// Each entry is a closure that returns the document at that point.

    func start() {
        guard !isStreaming else { return }
        isStreaming = true
        // Start from current position (allows resume after stop)
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isStreaming = false
    }

    func reset() {
        stop()
        tokenIndex = 0
        document = Document(sections: [])
    }

    private func tick() {
        guard tokenIndex < snapshots.count else {
            stop()
            return
        }
        document = snapshots[tokenIndex]()
        tokenIndex += 1
    }
}

// MARK: - Snapshot Builder

extension StreamSimulator {

    /// Builds an array of document snapshots that simulate a multi-message
    /// streaming conversation. Each snapshot is one "frame" of the stream.
    static func buildSnapshots() -> [() -> Document] {
        var snapshots: [() -> Document] = []

        // --- Static user message (appears all at once) ---

        let userSection = DocSection.message(
            id: "msg-1",
            role: "user",
            author: "minsheng",
            timestamp: "2:31 PM",
            blocks: [
                .paragraph(
                    "Can you explain how the height cache works in DocViewLayout? "
                    + "I want to understand the invalidation strategy."
                ),
            ]
        )

        snapshots.append { Document(sections: [userSection]) }

        // --- Assistant message streamed token by token ---

        let assistantTokens = tokenize("""
        Sure! The height cache in `DocViewLayout` is keyed on `(FlatBlock, contentWidth)`. \
        Since `FlatBlock` is `Hashable` and includes content, indent, and decoration, \
        any change to a block's data produces a cache miss — triggering re-measurement.

        The cache is cleared in only one situation: when the collection view's width changes. \
        This is detected at the start of `prepare()` by comparing the new width to the stored \
        `contentWidth`. Width changes are rare (window resize, rotation) so the cache is \
        long-lived during normal scrolling and streaming.

        During streaming, the typical pattern is:

        1. A new token arrives and the last block's content changes.
        2. `setDocument` is called with the updated document.
        3. The identity diff finds no structural changes (same BlockIDs).
        4. The content diff detects the last block changed and calls `reconfigureItems`.
        5. Layout invalidation triggers `prepare()`.
        6. The height cache hits on every block **except** the last one.
        7. Only the last block is re-measured — all others are O(1) lookups.

        This means a document with 500 blocks only measures 1 block per frame during streaming, \
        instead of all 500. The cost is proportional to the number of *changed* blocks, not the \
        total number of blocks.

        ```swift
        private struct HeightCacheKey: Hashable {
            var block: FlatBlock
            var width: CGFloat
        }
        private var heightCache: [HeightCacheKey: CGFloat] = [:]
        ```

        The cache key uses the full `FlatBlock` value, so it's automatically correct — \
        no manual invalidation needed beyond the width check.
        """)

        // Build incremental document snapshots for each token chunk
        var currentText = ""
        for token in assistantTokens {
            currentText += token
            let text = currentText
            snapshots.append {
                let blocks = Self.parseAssistantBlocks(from: text, sectionID: "msg-2")
                let assistantSection = DocSection.message(
                    id: "msg-2",
                    role: "assistant",
                    author: "Agent",
                    timestamp: "2:31 PM",
                    blocks: blocks
                )
                return Document(sections: [userSection, assistantSection])
            }
        }

        // --- Second user message (appears all at once after streaming ends) ---
        let finalText = currentText
        let userSection2 = DocSection.message(
            id: "msg-3",
            role: "user",
            author: "minsheng",
            timestamp: "2:32 PM",
            blocks: [
                .paragraph("That makes sense. What about scroll tracking?"),
            ]
        )

        snapshots.append {
            let blocks = Self.parseAssistantBlocks(from: finalText, sectionID: "msg-2")
            let assistantSection = DocSection.message(
                id: "msg-2",
                role: "assistant",
                author: "Agent",
                timestamp: "2:31 PM",
                blocks: blocks
            )
            return Document(sections: [userSection, assistantSection, userSection2])
        }

        // --- Second assistant response streamed ---
        let assistantTokens2 = tokenize("""
        Scroll tracking is controlled by the `scrollTracking` property on `DocCollectionViewController`. \
        When set to `.trackTail`, the view auto-scrolls to the bottom whenever content grows — \
        but only if the user hasn't manually scrolled away.

        The detection works like this:

        - After each `setDocument`, we compare the new content height to the previous height.
        - If it grew and the user is near the bottom, we scroll down.
        - If the user has scrolled up (more than 50pt from the bottom), we set `isUserScrolledAway = true` and stop auto-scrolling.
        - When the user scrolls back to the bottom, `isUserScrolledAway` resets to `false`.

        This gives the expected UX: streaming auto-scrolls like a terminal, but scrolling up to read earlier content won't get yanked back down.
        """)

        var currentText2 = ""
        for token in assistantTokens2 {
            currentText2 += token
            let text2 = currentText2
            snapshots.append {
                let blocks1 = Self.parseAssistantBlocks(from: finalText, sectionID: "msg-2")
                let assistantSection1 = DocSection.message(
                    id: "msg-2",
                    role: "assistant",
                    author: "Agent",
                    timestamp: "2:31 PM",
                    blocks: blocks1
                )
                let blocks2 = Self.parseAssistantBlocks(from: text2, sectionID: "msg-4")
                let assistantSection2 = DocSection.message(
                    id: "msg-4",
                    role: "assistant",
                    author: "Agent",
                    timestamp: "2:32 PM",
                    blocks: blocks2
                )
                return Document(sections: [
                    userSection, assistantSection1, userSection2, assistantSection2,
                ])
            }
        }

        return snapshots
    }

    /// Naive markdown-to-blocks parser: splits on double newlines, detects
    /// code fences and ordered lists. Good enough for demo purposes.
    static func parseAssistantBlocks(from text: String, sectionID: String) -> [FlatBlock] {
        var blocks: [FlatBlock] = []
        var current = ""
        var inCodeBlock = false
        var codeLanguage: String?
        var codeContent = ""

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    let idx = blocks.count
                    blocks.append(.codeBlock(language: codeLanguage, codeContent))
                    blocks[blocks.count - 1].id = BlockID(
                        sectionID: sectionID, index: idx, kind: .codeBlock
                    )
                    codeContent = ""
                    codeLanguage = nil
                    inCodeBlock = false
                } else {
                    // Flush current text as paragraph if non-empty
                    let flushed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !flushed.isEmpty {
                        let idx = blocks.count
                        blocks.append(.paragraph(flushed))
                        blocks[blocks.count - 1].id = BlockID(
                            sectionID: sectionID, index: idx, kind: .paragraph
                        )
                    }
                    current = ""
                    // Start code block
                    inCodeBlock = true
                    let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeLanguage = lang.isEmpty ? nil : lang
                }
            } else if inCodeBlock {
                if !codeContent.isEmpty { codeContent += "\n" }
                codeContent += String(line)
            } else if trimmed.isEmpty {
                // Flush paragraph
                let flushed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !flushed.isEmpty {
                    let idx = blocks.count
                    // Detect ordered list items
                    if let (number, text) = parseOrderedListItem(flushed) {
                        blocks.append(.paragraph(text, indent: 1, decoration: .ordered(number)))
                    } else if let bulletText = parseBulletListItem(flushed) {
                        blocks.append(.paragraph(bulletText, indent: 1, decoration: .bullet))
                    } else {
                        blocks.append(.paragraph(flushed))
                    }
                    blocks[blocks.count - 1].id = BlockID(
                        sectionID: sectionID, index: idx, kind: blocks[blocks.count - 1].kind
                    )
                }
                current = ""
            } else {
                if !current.isEmpty { current += " " }
                current += trimmed
            }
        }

        // Flush remaining
        if inCodeBlock && !codeContent.isEmpty {
            // Incomplete code block — still show it
            let idx = blocks.count
            blocks.append(.codeBlock(language: codeLanguage, codeContent))
            blocks[blocks.count - 1].id = BlockID(
                sectionID: sectionID, index: idx, kind: .codeBlock
            )
        } else {
            let flushed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !flushed.isEmpty {
                let idx = blocks.count
                if let (number, text) = parseOrderedListItem(flushed) {
                    blocks.append(.paragraph(text, indent: 1, decoration: .ordered(number)))
                } else if let bulletText = parseBulletListItem(flushed) {
                    blocks.append(.paragraph(bulletText, indent: 1, decoration: .bullet))
                } else {
                    blocks.append(.paragraph(flushed))
                }
                blocks[blocks.count - 1].id = BlockID(
                    sectionID: sectionID, index: idx, kind: blocks[blocks.count - 1].kind
                )
            }
        }

        return blocks
    }

    private static func parseOrderedListItem(_ text: String) -> (Int, String)? {
        let pattern = /^(\d+)\.\s+(.+)$/
        guard let match = text.wholeMatch(of: pattern) else { return nil }
        guard let num = Int(match.1) else { return nil }
        return (num, String(match.2))
    }

    private static func parseBulletListItem(_ text: String) -> String? {
        let pattern = /^-\s+(.+)$/
        guard let match = text.wholeMatch(of: pattern) else { return nil }
        return String(match.1)
    }
}

// MARK: - Tokenizer

/// Splits text into small chunks that simulate LLM token delivery.
/// Produces ~3-6 character chunks for realistic streaming speed.
private func tokenize(_ text: String) -> [String] {
    var tokens: [String] = []
    var remaining = text[...]
    while !remaining.isEmpty {
        // Variable chunk size: 2–8 chars, biased toward word boundaries
        let maxChunk = min(remaining.count, Int.random(in: 2...8))
        let chunk = remaining.prefix(maxChunk)

        // Try to break at a space within the chunk for natural feel
        if let spaceIdx = chunk.lastIndex(of: " "), spaceIdx > chunk.startIndex {
            let end = chunk.index(after: spaceIdx)
            tokens.append(String(remaining[remaining.startIndex..<end]))
            remaining = remaining[end...]
        } else {
            tokens.append(String(chunk))
            remaining = remaining.dropFirst(maxChunk)
        }
    }
    return tokens
}
