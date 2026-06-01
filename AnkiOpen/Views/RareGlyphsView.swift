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
                                Text(String(item.finding.scalar))
                                    .flashcardCJKFont(size: 32, relativeTo: .title2)
                                    .frame(width: 44, height: 44)
                                    .background(.thinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.finding.codePoint)
                                        .font(.headline)
                                    Text(item.finding.category.rawValue)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("\(item.occurrences) occurrences in \(item.cards.count) cards")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
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
                    Text(String(item.finding.scalar))
                        .flashcardCJKFont(size: 56, relativeTo: .largeTitle)
                        .frame(width: 76, height: 76)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Code point", value: item.finding.codePoint)
                        LabeledContent("Range", value: item.finding.category.rawValue)
                        LabeledContent("Occurrences", value: "\(item.occurrences)")
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
