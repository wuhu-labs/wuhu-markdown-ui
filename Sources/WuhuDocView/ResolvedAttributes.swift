@preconcurrency import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - ResolvedAttributes

/// Resolves `AttributedString` styling for different block kinds.
/// This is the theming surface — fonts, colors, paragraph styles per kind.
public struct ResolvedAttributes: @unchecked Sendable {

    public func applyStyle(
        to content: AttributedString,
        kind: BlockKind
    ) -> NSAttributedString {
        var styled = content

        let font: PlatformFont
        let textColor: PlatformColor

        switch kind {
        case .heading(let level):
            let size: CGFloat = switch level {
            case 1: 28
            case 2: 22
            case 3: 18
            case 4: 16
            default: 15
            }
            font = .systemFont(ofSize: size, weight: level <= 2 ? .bold : .semibold)
            textColor = .label

        case .paragraph, .blockquote:
            font = .systemFont(ofSize: 14, weight: .regular)
            textColor = .label

        default:
            font = .systemFont(ofSize: 14, weight: .regular)
            textColor = .label
        }

        let container = AttributeContainer
            .font(font)
            .foregroundColor(textColor)
        styled.mergeAttributes(container, mergePolicy: .keepCurrent)

        // Style link runs: underline + accent color.
        for run in styled.runs {
            guard run.link != nil else { continue }
            let linkStyle = AttributeContainer
                .foregroundColor(PlatformColor.linkColor)
                .underlineStyle(.single)
            styled[run.range].mergeAttributes(linkStyle, mergePolicy: .keepNew)
        }

        return NSAttributedString(styled)
    }

    public init() {}
}

// MARK: - Platform Aliases

#if canImport(AppKit)
public typealias PlatformFont = NSFont
public typealias PlatformColor = NSColor

extension NSColor {
    /// Alias so `.label` works on macOS like UIKit.
    static var label: NSColor { .labelColor }
}
#elseif canImport(UIKit)
public typealias PlatformFont = UIFont
public typealias PlatformColor = UIColor

extension UIColor {
    /// Alias so `.linkColor` works on iOS like AppKit.
    static var linkColor: UIColor { .link }
}
#endif
