import Testing
@testable import WuhuDocView

@Suite("contentChangedBlockIDs")
struct ContentChangedBlockIDsTests {

    // MARK: - Helpers

    private func blockID(section: String, index: Int, kind: BlockKind = .paragraph) -> BlockID {
        BlockID(sectionID: section, index: index, kind: kind)
    }

    private func paragraph(_ text: String, section: String, index: Int) -> FlatBlock {
        FlatBlock(
            id: blockID(section: section, index: index),
            content: .text(InlineContent(plain: text))
        )
    }

    private func doc(_ sections: [DocSection]) -> Document {
        Document(sections: sections)
    }

    // MARK: - Tests

    @Test("Identical documents produce no changes")
    func identicalDocuments() {
        let section = DocSection(id: "s1", blocks: [
            paragraph("Hello", section: "s1", index: 0),
            paragraph("World", section: "s1", index: 1),
        ])
        let old = doc([section])
        let new = doc([section])

        let changed = contentChangedBlockIDs(old: old, new: new)
        #expect(changed.isEmpty)
    }

    @Test("Empty to non-empty produces no changes (all inserts)")
    func emptyToNonEmpty() {
        let old = doc([])
        let new = doc([DocSection(id: "s1", blocks: [
            paragraph("Hello", section: "s1", index: 0),
        ])])

        let changed = contentChangedBlockIDs(old: old, new: new)
        #expect(changed.isEmpty)
    }

    @Test("Content change in existing block is detected")
    func contentChange() {
        let oldSection = DocSection(id: "s1", blocks: [
            paragraph("Hello", section: "s1", index: 0),
            paragraph("World", section: "s1", index: 1),
        ])
        let newSection = DocSection(id: "s1", blocks: [
            paragraph("Hello", section: "s1", index: 0),
            paragraph("World!!!", section: "s1", index: 1),
        ])

        let changed = contentChangedBlockIDs(old: doc([oldSection]), new: doc([newSection]))
        #expect(changed == [blockID(section: "s1", index: 1)])
    }

    @Test("New block in existing section is not a content change")
    func newBlockInSection() {
        let oldSection = DocSection(id: "s1", blocks: [
            paragraph("Hello", section: "s1", index: 0),
        ])
        let newSection = DocSection(id: "s1", blocks: [
            paragraph("Hello", section: "s1", index: 0),
            paragraph("World", section: "s1", index: 1),
        ])

        let changed = contentChangedBlockIDs(old: doc([oldSection]), new: doc([newSection]))
        #expect(changed.isEmpty)
    }

    @Test("Removed block is not reported as content change")
    func removedBlock() {
        let oldSection = DocSection(id: "s1", blocks: [
            paragraph("Hello", section: "s1", index: 0),
            paragraph("World", section: "s1", index: 1),
        ])
        let newSection = DocSection(id: "s1", blocks: [
            paragraph("Hello", section: "s1", index: 0),
        ])

        let changed = contentChangedBlockIDs(old: doc([oldSection]), new: doc([newSection]))
        #expect(changed.isEmpty)
    }

    @Test("Multiple content changes across sections")
    func multipleSections() {
        let oldSections = [
            DocSection(id: "s1", blocks: [
                paragraph("A", section: "s1", index: 0),
                paragraph("B", section: "s1", index: 1),
            ]),
            DocSection(id: "s2", blocks: [
                paragraph("C", section: "s2", index: 0),
            ]),
        ]
        let newSections = [
            DocSection(id: "s1", blocks: [
                paragraph("A-changed", section: "s1", index: 0),
                paragraph("B", section: "s1", index: 1),
            ]),
            DocSection(id: "s2", blocks: [
                paragraph("C-changed", section: "s2", index: 0),
            ]),
        ]

        let changed = contentChangedBlockIDs(old: doc(oldSections), new: doc(newSections))
        #expect(changed.count == 2)
        #expect(changed.contains(blockID(section: "s1", index: 0)))
        #expect(changed.contains(blockID(section: "s2", index: 0)))
    }

    @Test("Indent change on existing block is a content change")
    func indentChange() {
        let oldBlock = FlatBlock(
            id: blockID(section: "s1", index: 0),
            content: .text(InlineContent(plain: "Hello")),
            indent: 0
        )
        let newBlock = FlatBlock(
            id: blockID(section: "s1", index: 0),
            content: .text(InlineContent(plain: "Hello")),
            indent: 1
        )

        let old = doc([DocSection(id: "s1", blocks: [oldBlock])])
        let new = doc([DocSection(id: "s1", blocks: [newBlock])])

        let changed = contentChangedBlockIDs(old: old, new: new)
        #expect(changed == [blockID(section: "s1", index: 0)])
    }

    @Test("Decoration change on existing block is a content change")
    func decorationChange() {
        let oldBlock = FlatBlock(
            id: blockID(section: "s1", index: 0),
            content: .text(InlineContent(plain: "Hello")),
            indent: 1,
            decoration: .bullet
        )
        let newBlock = FlatBlock(
            id: blockID(section: "s1", index: 0),
            content: .text(InlineContent(plain: "Hello")),
            indent: 1,
            decoration: .ordered(1)
        )

        let old = doc([DocSection(id: "s1", blocks: [oldBlock])])
        let new = doc([DocSection(id: "s1", blocks: [newBlock])])

        let changed = contentChangedBlockIDs(old: old, new: new)
        #expect(changed == [blockID(section: "s1", index: 0)])
    }
}
