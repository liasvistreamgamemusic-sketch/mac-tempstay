import AppKit
import SwiftUI

/// The shelf's SwiftUI surface: a header with the item count and a clear
/// button, then the stack of draggable items (or an empty-state hint).
struct ShelfView: View {
    @ObservedObject var store: ShelfStore

    /// Builds the drag pasteboard provider for an item being dragged out.
    let makeProvider: (ShelfItem) -> NSItemProvider?
    /// Open / preview an item (double-click).
    let onOpen: (ShelfItem) -> Void
    /// Remove a single item.
    let onRemove: (ShelfItem) -> Void
    /// Clear the whole shelf.
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ShelfMetrics.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ShelfMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "tray.full.fill")
                .foregroundStyle(.secondary)
            Text(AppInfo.name)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            if !store.isEmpty {
                Text("\(store.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Button(action: onClear) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("シェルフを空にする")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: ShelfMetrics.headerHeight)
    }

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(store.items) { item in
                    ShelfItemRow(
                        item: item,
                        contentURL: store.contentURL(for: item),
                        onOpen: { onOpen(item) },
                        onRemove: { onRemove(item) }
                    )
                    .onDrag { makeProvider(item) ?? NSItemProvider() }
                }
            }
            .padding(8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("ここにドラッグ")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("ファイル・画像・テキストを\n一時的に置けます")
                .font(.system(size: 10))
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// A single draggable row: thumbnail, title and subtitle, with a delete button
/// that appears on hover.
struct ShelfItemRow: View {
    let item: ShelfItem
    let contentURL: URL?
    let onOpen: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: ItemThumbnail.image(for: item, contentURL: contentURL, side: ShelfMetrics.thumbnailSide))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: ShelfMetrics.thumbnailSide, height: ShelfMetrics.thumbnailSide)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let subtitle = ItemFormat.subtitle(for: item) {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)

            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("削除")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.08) : Color.primary.opacity(0.03))
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2, perform: onOpen)
        .help(item.title)
    }
}

/// Layout constants for the shelf, kept in one place so the window controller
/// and views agree on sizing.
enum ShelfMetrics {
    static let width: CGFloat = 240
    static let height: CGFloat = 420
    static let cornerRadius: CGFloat = 16
    static let headerHeight: CGFloat = 34
    static let thumbnailSide: CGFloat = 36
    /// Gap between the shelf and the physical screen edge.
    static let edgeGap: CGFloat = 8
}
