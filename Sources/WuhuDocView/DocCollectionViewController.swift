import SwiftUI

// MARK: - macOS
#if canImport(AppKit)
import AppKit

public final class DocCollectionViewController: NSViewController {

    private(set) var document: Document = Document(sections: [])

    /// Optional external factory for custom block views. When set, this is
    /// tried first for `.custom` blocks; returning `nil` falls back to the
    /// built-in views (docHeader, messageHeader, toolCall, etc.).
    public var customBlockView: (@MainActor (FlatBlock) -> AnyView?)? {
        didSet { syncCustomBlockView() }
    }

    /// Called when the user clicks a link in a text block.
    public var onOpenURL: ((URL) -> Void)?

    private lazy var scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.hasVerticalScroller = true; sv.hasHorizontalScroller = false
        sv.autohidesScrollers = true
        sv.drawsBackground = true; sv.backgroundColor = .windowBackgroundColor
        sv.wantsLayer = true
        return sv
    }()

    private lazy var collectionView: NSCollectionView = {
        let cv = NSCollectionView()
        cv.backgroundColors = [.clear]
        cv.isSelectable = false
        return cv
    }()

    private let docLayout = DocViewLayout()
    private var dataSource: NSCollectionViewDiffableDataSource<String, BlockID>!

    public override func loadView() { self.view = NSView() }

    public override func viewDidLoad() {
        super.viewDidLoad()

        docLayout.dataProvider = { [weak self] in self?.document ?? Document(sections: []) }
        collectionView.collectionViewLayout = docLayout

        collectionView.register(TextBlockCell.self, forItemWithIdentifier: TextBlockCell.identifier)
        collectionView.register(CodeBlockCell.self, forItemWithIdentifier: CodeBlockCell.identifier)
        collectionView.register(HostedSwiftUICell.self, forItemWithIdentifier: HostedSwiftUICell.identifier)
        collectionView.register(ThematicBreakCell.self, forItemWithIdentifier: ThematicBreakCell.identifier)

        scrollView.documentView = collectionView
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        dataSource = NSCollectionViewDiffableDataSource<String, BlockID>(
            collectionView: collectionView
        ) { [weak self] cv, ip, _ in self?.makeItem(cv: cv, indexPath: ip) ?? NSCollectionViewItem() }

        syncCustomBlockView()
    }

    private func syncCustomBlockView() {
        docLayout.registry.customMeasurer = CustomBlockMeasurer(
            customBlockView: customBlockView
        )
    }

    public func setDocument(_ doc: Document) {
        self.document = doc
        applySnapshot()
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<String, BlockID>()
        for section in document.sections {
            snapshot.appendSections([section.id])
            snapshot.appendItems(section.blocks.map(\.id), toSection: section.id)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func makeItem(cv: NSCollectionView, indexPath: IndexPath) -> NSCollectionViewItem {
        let block = document.sections[indexPath.section].blocks[indexPath.item]

        switch block.content {
        case .text:
            let item = cv.makeItem(withIdentifier: TextBlockCell.identifier, for: indexPath) as! TextBlockCell
            item.configure(with: block, resolvedAttributes: docLayout.resolvedAttributes, indentWidth: docLayout.registry.indentWidth)
            item.onOpenURL = onOpenURL
            return item

        case .codeBlock(let code):
            let item = cv.makeItem(withIdentifier: CodeBlockCell.identifier, for: indexPath) as! CodeBlockCell
            item.configure(with: code)
            return item

        case .thematicBreak:
            return cv.makeItem(withIdentifier: ThematicBreakCell.identifier, for: indexPath)

        case .table, .image, .custom:
            // All view-based blocks: get the view from the registry
            let item = cv.makeItem(withIdentifier: HostedSwiftUICell.identifier, for: indexPath) as! HostedSwiftUICell
            if let swiftUIView = docLayout.registry.swiftUIView(for: block) {
                item.configure(with: swiftUIView)
            }
            return item
        }
    }
}

// MARK: - iOS
#elseif canImport(UIKit)
import UIKit

public final class DocCollectionViewController: UIViewController {

    private(set) var document: Document = Document(sections: [])

    /// Optional external factory for custom block views. When set, this is
    /// tried first for `.custom` blocks; returning `nil` falls back to the
    /// built-in views (docHeader, messageHeader, toolCall, etc.).
    public var customBlockView: (@MainActor (FlatBlock) -> AnyView?)? {
        didSet { syncCustomBlockView() }
    }

    /// Called when the user taps a link in a text block.
    public var onOpenURL: ((URL) -> Void)?

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: docLayout)
        cv.backgroundColor = .systemBackground
        return cv
    }()

    private let docLayout = DocViewLayout()
    private var dataSource: UICollectionViewDiffableDataSource<String, BlockID>!

    public override func viewDidLoad() {
        super.viewDidLoad()

        docLayout.dataProvider = { [weak self] in self?.document ?? Document(sections: []) }

        collectionView.register(TextBlockCell.self, forCellWithReuseIdentifier: TextBlockCell.reuseIdentifier)
        collectionView.register(CodeBlockCell.self, forCellWithReuseIdentifier: CodeBlockCell.reuseIdentifier)
        collectionView.register(HostedSwiftUICell.self, forCellWithReuseIdentifier: HostedSwiftUICell.reuseIdentifier)
        collectionView.register(ThematicBreakCell.self, forCellWithReuseIdentifier: ThematicBreakCell.reuseIdentifier)

        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        dataSource = UICollectionViewDiffableDataSource<String, BlockID>(
            collectionView: collectionView
        ) { [weak self] cv, ip, _ in self?.makeCell(cv: cv, indexPath: ip) ?? UICollectionViewCell() }

        syncCustomBlockView()
    }

    private func syncCustomBlockView() {
        docLayout.registry.customMeasurer = CustomBlockMeasurer(
            customBlockView: customBlockView
        )
    }

    public func setDocument(_ doc: Document) {
        self.document = doc
        applySnapshot()
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<String, BlockID>()
        for section in document.sections {
            snapshot.appendSections([section.id])
            snapshot.appendItems(section.blocks.map(\.id), toSection: section.id)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func makeCell(cv: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        let block = document.sections[indexPath.section].blocks[indexPath.item]

        switch block.content {
        case .text:
            let cell = cv.dequeueReusableCell(withReuseIdentifier: TextBlockCell.reuseIdentifier, for: indexPath) as! TextBlockCell
            cell.configure(with: block, resolvedAttributes: docLayout.resolvedAttributes, indentWidth: docLayout.registry.indentWidth)
            cell.onOpenURL = onOpenURL
            return cell

        case .codeBlock(let code):
            let cell = cv.dequeueReusableCell(withReuseIdentifier: CodeBlockCell.reuseIdentifier, for: indexPath) as! CodeBlockCell
            cell.configure(with: code)
            return cell

        case .thematicBreak:
            return cv.dequeueReusableCell(withReuseIdentifier: ThematicBreakCell.reuseIdentifier, for: indexPath)

        case .table, .image, .custom:
            // All view-based blocks: get the view from the registry
            let cell = cv.dequeueReusableCell(withReuseIdentifier: HostedSwiftUICell.reuseIdentifier, for: indexPath) as! HostedSwiftUICell
            if let swiftUIView = docLayout.registry.swiftUIView(for: block) {
                cell.configure(with: swiftUIView, parentController: self)
            }
            return cell
        }
    }
}
#endif
