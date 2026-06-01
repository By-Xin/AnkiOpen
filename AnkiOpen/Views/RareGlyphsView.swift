import CoreData
import SwiftUI

struct RareGlyphsView: View {
    @FetchRequest private var cards: FetchedResults<FlashcardMO>

    init() {
        let request = FlashcardMO.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FlashcardMO.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \FlashcardMO.createdAt, ascending: false)
        ]
        _cards = FetchRequest(fetchRequest: request, animation: .default)
    }

    private var items: [GlyphInventoryItem] {
        GlyphInventory.items(for: Array(cards))
    }

    var body: some View {
        List {
            if items.isEmpty {
                EmptyStateView(
                    title: "No Rare Glyphs",
                    systemImage: "textformat.alt",
                    message: "Imported cards do not currently contain high-risk glyphs."
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                Section("Glyphs") {
                    ForEach(items) { item in
                        NavigationLink {
                            RareGlyphDetailView(item: item)
                        } label: {
                            HStack(spacing: 14) {
                                GlyphPreview(scalar: item.finding.scalar, size: 44)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.finding.codePoint)
                                        .font(.headline)
                                    Text(item.finding.category.rawValue)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("\(item.occurrences) occurrences in \(item.cards.count) cards")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    GlyphFallbackStatusLabel(finding: item.finding)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Rare Glyphs")
    }
}

private struct RareGlyphDetailView: View {
    let item: GlyphInventoryItem

    var body: some View {
        List {
            Section("Glyph") {
                HStack(spacing: 16) {
                    GlyphPreview(scalar: item.finding.scalar, size: 76)

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Code point", value: item.finding.codePoint)
                        LabeledContent("Range", value: item.finding.category.rawValue)
                        LabeledContent("Occurrences", value: "\(item.occurrences)")
                        LabeledContent("Fallback", value: item.finding.fallbackStatusTitle)
                    }
                }
            }

            Section("Cards") {
                ForEach(item.cards) { card in
                    VStack(alignment: .leading, spacing: 6) {
                        FlashcardText(
                            text: card.front,
                            size: 17,
                            relativeTo: .headline,
                            weight: .semibold,
                            lineLimit: 2
                        )
                        .foregroundStyle(.primary)

                        FlashcardText(
                            text: card.back,
                            size: 15,
                            relativeTo: .subheadline,
                            weight: .regular,
                            lineLimit: 2
                        )
                        .foregroundStyle(.secondary)

                        Text("\(card.notebook.name) / \(card.unit?.name ?? "Default")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .navigationTitle(item.finding.codePoint)
    }
}

private struct GlyphFallbackStatusLabel: View {
    let finding: GlyphDiagnostics.Finding

    var body: some View {
        Label(finding.fallbackStatusTitle, systemImage: finding.hasFallback ? "checkmark.circle" : "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(finding.hasFallback ? .green : .orange)
    }
}

private struct GlyphPreview: View {
    let scalar: UnicodeScalar
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.thinMaterial)
            if let imageName = GlyphFallbackAsset.imageName(for: scalar) {
                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.primary)
                    .padding(size * 0.14)
            } else {
                Text(String(scalar))
                    .flashcardCJKFont(size: size * 0.7, relativeTo: .title2)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(String(scalar)))
    }
}
