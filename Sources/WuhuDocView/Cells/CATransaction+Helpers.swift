import QuartzCore

/// Suppresses implicit `CALayer` animations for the duration of `body`.
///
/// ```swift
/// withNoAnimation {
///     layer.frame = newFrame
///     layer.contents = nil
/// }
/// ```
func withNoAnimation(_ body: () -> Void) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    body()
    CATransaction.commit()
}
