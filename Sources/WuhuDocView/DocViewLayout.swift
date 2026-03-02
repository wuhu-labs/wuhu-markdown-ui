#if canImport(AppKit)
import AppKit

/// Custom `NSCollectionViewLayout` that computes all cell frames in
/// `prepare()` using the block measurer registry and spacing table.
///
/// No self-sizing negotiation. The layout owns all geometry. It reads from
/// the data source directly (via its `dataProvider`) to determine block
/// kinds, indentation, and content for measurement.
public final class DocViewLayout: NSCollectionViewLayout {

    // MARK: - Configuration

    public var spacingTable: SpacingTable = .default
    public var registry: BlockMeasurerRegistry = .init()
    public var resolvedAttributes: ResolvedAttributes = .init()

    /// Closure that provides the document data. The layout reads this during
    /// `prepare()`. Set by the view controller / coordinator.
    public var dataProvider: (() -> Document)?

    // MARK: - Cached State

    private var cachedAttributes: [IndexPath: NSCollectionViewLayoutAttributes] = [:]
    private var contentHeight: CGFloat = 0
    private var contentWidth: CGFloat = 0

    // MARK: - Layout Core

    public override func prepare() {
        super.prepare()
        cachedAttributes.removeAll()

        guard let collectionView, let document = dataProvider?() else {
            contentHeight = 0
            return
        }

        contentWidth = collectionView.bounds.width
        let availableWidth = contentWidth
        var y: CGFloat = registry.contentInsets  // top padding

        for (sectionIndex, section) in document.sections.enumerated() {
            // Section spacing (except before first section)
            if sectionIndex > 0 {
                y += spacingTable.sectionSpacing
            }

            for (itemIndex, block) in section.blocks.enumerated() {
                // Inter-block spacing within section
                if itemIndex > 0 {
                    let prevKind = section.blocks[itemIndex - 1].kind
                    y += spacingTable.spacing(prevKind, block.kind)
                }

                let height = registry.measureHeight(
                    of: block,
                    availableWidth: availableWidth,
                    resolvedAttributes: resolvedAttributes
                )
                let leadingX = registry.leadingOffset(for: block)
                let blockWidth = registry.contentWidth(
                    for: block, availableWidth: availableWidth
                )

                let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                let attrs = NSCollectionViewLayoutAttributes(forItemWith: indexPath)
                attrs.frame = CGRect(x: leadingX, y: y, width: blockWidth, height: height)
                cachedAttributes[indexPath] = attrs

                y += height
            }
        }

        y += registry.contentInsets  // bottom padding
        contentHeight = y
    }

    public override var collectionViewContentSize: NSSize {
        NSSize(width: contentWidth, height: contentHeight)
    }

    public override func layoutAttributesForElements(
        in rect: NSRect
    ) -> [NSCollectionViewLayoutAttributes] {
        // Simple linear scan. For large documents, switch to binary search on Y.
        cachedAttributes.values.filter { $0.frame.intersects(rect) }
    }

    public override func layoutAttributesForItem(
        at indexPath: IndexPath
    ) -> NSCollectionViewLayoutAttributes? {
        cachedAttributes[indexPath]
    }

    public override func shouldInvalidateLayout(
        forBoundsChange newBounds: NSRect
    ) -> Bool {
        // Invalidate when width changes (need to re-measure text heights)
        guard let cv = collectionView else { return false }
        return cv.bounds.width != newBounds.width
    }

    // MARK: - Incremental Invalidation

    /// Invalidate layout from a specific index path onward. Used during
    /// streaming when only the last block (and everything after it) needs
    /// recomputation.
    public func invalidateLayout(from indexPath: IndexPath) {
        // For the POC, just invalidate everything. The incremental path
        // will be optimized later.
        invalidateLayout()
    }
}

#elseif canImport(UIKit)
import UIKit

/// Custom `UICollectionViewLayout` ��� same logic as the AppKit version.
public final class DocViewLayout: UICollectionViewLayout {

    public var spacingTable: SpacingTable = .default
    public var registry: BlockMeasurerRegistry = .init()
    public var resolvedAttributes: ResolvedAttributes = .init()
    public var dataProvider: (() -> Document)?

    private var cachedAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var contentHeight: CGFloat = 0
    private var contentWidth: CGFloat = 0

    public override func prepare() {
        super.prepare()
        cachedAttributes.removeAll()

        guard let collectionView, let document = dataProvider?() else {
            contentHeight = 0
            return
        }

        contentWidth = collectionView.bounds.width
        let availableWidth = contentWidth
        var y: CGFloat = registry.contentInsets

        for (sectionIndex, section) in document.sections.enumerated() {
            if sectionIndex > 0 {
                y += spacingTable.sectionSpacing
            }

            for (itemIndex, block) in section.blocks.enumerated() {
                if itemIndex > 0 {
                    let prevKind = section.blocks[itemIndex - 1].kind
                    y += spacingTable.spacing(prevKind, block.kind)
                }

                let height = registry.measureHeight(
                    of: block,
                    availableWidth: availableWidth,
                    resolvedAttributes: resolvedAttributes
                )
                let leadingX = registry.leadingOffset(for: block)
                let blockWidth = registry.contentWidth(
                    for: block, availableWidth: availableWidth
                )

                let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
                let attrs = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                attrs.frame = CGRect(x: leadingX, y: y, width: blockWidth, height: height)
                cachedAttributes[indexPath] = attrs

                y += height
            }
        }

        y += registry.contentInsets
        contentHeight = y
    }

    public override var collectionViewContentSize: CGSize {
        CGSize(width: contentWidth, height: contentHeight)
    }

    public override func layoutAttributesForElements(
        in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {
        cachedAttributes.values.filter { $0.frame.intersects(rect) }
    }

    public override func layoutAttributesForItem(
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        cachedAttributes[indexPath]
    }

    public override func shouldInvalidateLayout(
        forBoundsChange newBounds: CGRect
    ) -> Bool {
        guard let cv = collectionView else { return false }
        return cv.bounds.width != newBounds.width
    }

    public func invalidateLayout(from indexPath: IndexPath) {
        invalidateLayout()
    }
}
#endif
