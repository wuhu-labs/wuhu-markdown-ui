import SwiftUI

// MARK: - Custom Block Views (SwiftUI, cross-platform)

/// These SwiftUI views are the "data as view" layer: each one is instantiated
/// once per block, hosted in an NSHostingView/UIHostingView, and measured via
/// sizeThatFits. They are the source of truth for both rendering and height.

// MARK: - Doc Header

struct DocHeaderView: View {
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Message Header

struct MessageHeaderView: View {
    let role: String
    let author: String
    let timestamp: String

    var body: some View {
        HStack(spacing: 6) {
            Text(author)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(role == "user" ? .orange : .purple)
            Text(timestamp)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tool Call

struct ToolCallView: View {
    let name: String
    let args: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "gearshape")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text(name)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
            Text(args)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Table

struct TableBlockView: View {
    let table: TableContent

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            // Header row
            GridRow {
                ForEach(Array(table.headers.enumerated()), id: \.offset) { _, header in
                    Text(header)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(.background.secondary)

            Divider()

            // Data rows
            ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(.system(size: 12))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .background(
                    rowIndex % 2 == 1
                        ? AnyShapeStyle(.background.secondary)
                        : AnyShapeStyle(.clear)
                )
            }
        }
    }
}

// MARK: - Fallback Custom Block

struct GenericCustomBlockView: View {
    let tag: String

    var body: some View {
        Text("[\(tag)]")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Custom Block View Factory

/// Given a `FlatBlock` with `.custom` content, returns the appropriate
/// SwiftUI view wrapped in `AnyView`. This is the dispatch point for
/// domain-specific block rendering.
@MainActor
func makeCustomBlockView(for block: FlatBlock) -> AnyView {
    guard case .custom(let content) = block.content,
          case .custom(let tag) = block.kind
    else {
        return AnyView(EmptyView())
    }

    switch tag {
    case "docHeader":
        return AnyView(DocHeaderView(
            title: content.fields["title"] ?? "Untitled",
            subtitle: content.fields["subtitle"]
        ))
    case "messageHeader":
        let role = content.fields["role"] ?? "unknown"
        return AnyView(MessageHeaderView(
            role: role,
            author: content.fields["author"] ?? role,
            timestamp: content.fields["timestamp"] ?? ""
        ))
    case "toolCall":
        return AnyView(ToolCallView(
            name: content.fields["name"] ?? "tool",
            args: content.fields["args"] ?? ""
        ))
    default:
        return AnyView(GenericCustomBlockView(tag: tag))
    }
}
