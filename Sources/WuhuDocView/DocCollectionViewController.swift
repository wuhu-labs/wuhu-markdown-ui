import SwiftUI

// MARK: - ScrollTracking

public enum ScrollTracking: Sendable {
    case manual     // no auto-scrolling
    case trackTail  // auto-scroll to bottom when content grows
}

// MARK: - Content Diffing

/// Compares two documents and returns the `BlockID`s of blocks whose content
/// changed (same identity, different value). Pure function — easy to test.
public func contentChangedBlockIDs(
    old: Document, new: Document
) -> [BlockID] {
    var changed: [BlockID] = []

    // Build a lookup of old sections by ID for efficient matching
    let oldSections: [String: DocSection] = Dictionary(
        old.sections.map { ($0.id, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    for newSection in new.sections {
        guard let oldSection = oldSections[newSection.id] else {
            // Entirely new section — handled by snapshot insert, not reconfigure
            continue
        }

        // Build lookup of old blocks by BlockID within this section
        let oldBlocks: [BlockID: FlatBlock] = Dictionary(
            oldSection.blocks.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for newBlock in newSection.blocks {
            if let oldBlock = oldBlocks[newBlock.id], oldBlock != newBlock {
                changed.append(newBlock.id)
            }
        }
    }

    return changed
}

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

    // MARK: - Scroll Tracking

    public var scrollTracking: ScrollTracking = .manual {
        didSet {
            if scrollTracking == .trackTail {
                isUserScrolledAway = false
                scrollToBottom(animated: false)
            }
        }
    }

    private var isUserScrolledAway: Bool = false
    private var previousContentHeight: CGFloat = 0
    private nonisolated(unsafe) var scrollObserver: NSObjectProtocol?

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

        // Observe scroll position for user-scroll-away detection
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleScrollChanged()
            }
        }
    }

    deinit {
        if let observer = scrollObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func syncCustomBlockView() {
        docLayout.registry.customMeasurer = CustomBlockMeasurer(
            customBlockView: customBlockView
        )
    }

    // MARK: - Set Document (Content-Aware Diff)

    public func setDocument(_ doc: Document) {
        guard doc != self.document else { return }

        let old = self.document
        self.document = doc

        // Step 1: Identity diff (inserts/deletes/moves)
        applySnapshot()

        // Step 2: Content diff (reload cells whose content changed)
        let changed = contentChangedBlockIDs(old: old, new: doc)
        if !changed.isEmpty {
            var snapshot = dataSource.snapshot()
            // AppKit's NSDiffableDataSourceSnapshot doesn't have
            // reconfigureItems; use reloadItems instead.
            snapshot.reloadItems(changed)
            dataSource.apply(snapshot, animatingDifferences: false)
            collectionView.collectionViewLayout?.invalidateLayout()
        }

        // Step 3: Scroll tracking
        handleScrollTrackingAfterUpdate()
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<String, BlockID>()
        for section in document.sections {
            snapshot.appendSections([section.id])
            snapshot.appendItems(section.blocks.map(\.id), toSection: section.id)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Scroll Tracking (macOS)

    private func handleScrollTrackingAfterUpdate() {
        guard scrollTracking == .trackTail else { return }

        let newContentHeight = scrollView.documentView?.frame.height ?? 0
        defer { previousContentHeight = newContentHeight }

        guard newContentHeight > previousContentHeight, !isUserScrolledAway else { return }
        scrollToBottom(animated: false)
    }

    private func scrollToBottom(animated: Bool) {
        guard let documentView = scrollView.documentView else { return }
        let maxY = max(documentView.frame.height - scrollView.contentView.bounds.height, 0)
        let targetPoint = NSPoint(x: 0, y: maxY)
        if animated {
            scrollView.contentView.animator().setBoundsOrigin(targetPoint)
        } else {
            scrollView.contentView.scroll(to: targetPoint)
        }
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private var isNearBottom: Bool {
        guard let documentView = scrollView.documentView else { return true }
        let visibleMaxY = scrollView.contentView.bounds.origin.y + scrollView.contentView.bounds.height
        let contentMaxY = documentView.frame.height
        return contentMaxY - visibleMaxY < 50
    }

    private func handleScrollChanged() {
        guard scrollTracking == .trackTail else { return }
        isUserScrolledAway = !isNearBottom
    }

    // MARK: - Cell Factory

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

public final class DocCollectionViewController: UIViewController, UICollectionViewDelegate {

    private(set) var document: Document = Document(sections: [])

    /// Optional external factory for custom block views. When set, this is
    /// tried first for `.custom` blocks; returning `nil` falls back to the
    /// built-in views (docHeader, messageHeader, toolCall, etc.).
    public var customBlockView: (@MainActor (FlatBlock) -> AnyView?)? {
        didSet { syncCustomBlockView() }
    }

    /// Called when the user taps a link in a text block.
    public var onOpenURL: ((URL) -> Void)?

    // MARK: - Scroll Tracking

    public var scrollTracking: ScrollTracking = .manual {
        didSet {
            if scrollTracking == .trackTail {
                isUserScrolledAway = false
                scrollToBottom(animated: false)
            }
        }
    }

    private var isUserScrolledAway: Bool = false
    private var previousContentHeight: CGFloat = 0

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: docLayout)
        cv.backgroundColor = .systemBackground
        cv.delegate = self
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

    // MARK: - Set Document (Content-Aware Diff)

    public func setDocument(_ doc: Document) {
        guard doc != self.document else { return }

        let old = self.document
        self.document = doc

        // Step 1: Identity diff (inserts/deletes/moves)
        applySnapshot()

        // Step 2: Content diff (reconfigure cells whose content changed)
        let changed = contentChangedBlockIDs(old: old, new: doc)
        if !changed.isEmpty {
            var snapshot = dataSource.snapshot()
            snapshot.reconfigureItems(changed)
            dataSource.apply(snapshot, animatingDifferences: false)
            collectionView.collectionViewLayout.invalidateLayout()
        }

        // Step 3: Scroll tracking
        handleScrollTrackingAfterUpdate()
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<String, BlockID>()
        for section in document.sections {
            snapshot.appendSections([section.id])
            snapshot.appendItems(section.blocks.map(\.id), toSection: section.id)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Scroll Tracking (iOS)

    private func handleScrollTrackingAfterUpdate() {
        guard scrollTracking == .trackTail else { return }

        let newContentHeight = collectionView.contentSize.height
        defer { previousContentHeight = newContentHeight }

        guard newContentHeight > previousContentHeight, !isUserScrolledAway else { return }
        scrollToBottom(animated: false)
    }

    private func scrollToBottom(animated: Bool) {
        let contentHeight = collectionView.contentSize.height
        let viewHeight = collectionView.bounds.height
        let insetBottom = collectionView.adjustedContentInset.bottom
        let maxY = max(contentHeight - viewHeight + insetBottom, 0)
        collectionView.setContentOffset(CGPoint(x: 0, y: maxY), animated: animated)
    }

    private var isNearBottom: Bool {
        let contentHeight = collectionView.contentSize.height
        let viewHeight = collectionView.bounds.height
        let insetBottom = collectionView.adjustedContentInset.bottom
        let offsetY = collectionView.contentOffset.y
        let maxY = contentHeight - viewHeight + insetBottom
        return maxY - offsetY < 50
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollTracking == .trackTail else { return }
        isUserScrolledAway = !isNearBottom
    }

    // MARK: - Cell Factory

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
