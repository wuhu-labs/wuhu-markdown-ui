import SwiftUI

/// Measures and provides the SwiftUI view for custom (domain-specific) blocks.
/// Conforms to `ViewBasedBlockMeasuring` — delegates to the same view factory
/// used for cell rendering.
///
/// An optional external factory can be provided to handle additional custom
/// block types. When set, the external factory is tried first; if it returns
/// `nil`, the built-in `makeCustomBlockView` is used as a fallback.
public struct CustomBlockMeasurer: ViewBasedBlockMeasuring {

    /// External factory for custom block views. Returns `nil` to fall back
    /// to the built-in views.
    public var customBlockView: (@MainActor (FlatBlock) -> AnyView?)?

    public init(customBlockView: (@MainActor (FlatBlock) -> AnyView?)? = nil) {
        self.customBlockView = customBlockView
    }

    public func view(for block: FlatBlock) -> AnyView {
        if let externalView = customBlockView?(block) {
            return externalView
        }
        return makeCustomBlockView(for: block)
    }
}
