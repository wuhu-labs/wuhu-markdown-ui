import SwiftUI

/// Measures and provides the SwiftUI view for table blocks.
/// Conforms to `ViewBasedBlockMeasuring` — the same `TableBlockView` is used
/// for both measurement and cell rendering.
public struct TableBlockMeasurer: ViewBasedBlockMeasuring {
    public init() {}

    public func view(for block: FlatBlock) -> AnyView {
        guard case .table(let table) = block.content else {
            return AnyView(EmptyView())
        }
        return AnyView(TableBlockView(table: table))
    }
}
