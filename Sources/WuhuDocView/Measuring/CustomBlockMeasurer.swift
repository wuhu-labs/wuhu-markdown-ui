import SwiftUI

/// Measures and provides the SwiftUI view for custom (domain-specific) blocks.
/// Conforms to `ViewBasedBlockMeasuring` — delegates to the same view factory
/// used for cell rendering.
public struct CustomBlockMeasurer: ViewBasedBlockMeasuring {
    public init() {}

    public func view(for block: FlatBlock) -> AnyView {
        makeCustomBlockView(for: block)
    }
}
