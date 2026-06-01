import CoreData
import SwiftUI

struct UnitDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var unit: NotebookUnitMO
    @FetchRequest private var cards: FetchedResults<FlashcardMO>
    @State private var searchText = ""
    @State private var isShowingAddCard = false
    @State private var cardToEdit: FlashcardMO?
    @State private var errorMessage: String?
    @State private var isFillingAudio = false
    @State private var czyzdSummary: CZYZDAudioAttachmentSummary?

    private let czyzdAttachmentService = CZYZDAudioAttachmentService()

    init(unit: NotebookUnitMO) {
        self.unit = unit
        let request = FlashcardMO.fetchRequest()
        request.predicate = NSPredicate(format: "unit == %@ AND isArchived == NO", unit)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FlashcardMO.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \FlashcardMO.createdAt, ascending: false)
        ]
        _cards = FetchRequest(fetchRequest: request, animation: .default)
    }

    var filteredCards: [FlashcardMO] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            return Array(cards)
        }
        return cards.filter {
            $0.front.localizedCaseInsensitiveContains(term) || $0.back.localizedCaseInsensitiveContains(term)
        }
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    StudyView(initialNotebook: unit.notebook, initialUnit: unit)
                } label: {
                    Label("Study This Unit", systemImage: "rectangle.stack.badge.play")
                }

                Button {
                    Task {
                        await fillMissingAudio()
                    }
                } label: {
                    Label(
                        isFillingAudio ? "Filling CZYZD Audio..." : "Fill Missing CZYZD Audio",
                        systemImage: "speaker.wave.2.badge.plus"
                    )
                }
                .disabled(isFillingAudio || cards.isEmpty)
            }

            if let czyzdSummary {
                Section("CZYZD Audio") {
                    LabeledContent("Checked", value: "\(czyzdSummary.checkedCards)")
                    LabeledContent("Matched", value: "\(czyzdSummary.matchedCards)")
                    LabeledContent("Failed", value: "\(czyzdSummary.failedCards)")
                    if let messages = czyzdSummary.messageSummary {
                        Text(messages)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Cards") {
                ForEach(filteredCards) { card in
                    Button {
                        cardToEdit = card
                    } label: {
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
                            if GlyphDiagnostics.containsRiskyGlyphs(card.front + card.back) {
                                Label("Rare glyphs", systemImage: "textformat.alt")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Text("Due \(card.dueAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            archive(card)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search cards")
        .overlay {
            if cards.isEmpty {
                EmptyStateView(
                    title: "No Cards",
                    systemImage: "rectangle.stack",
                    message: "Add a card or import a CSV into this unit."
                )
            }
        }
        .navigationTitle(unit.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddCard = true
                } label: {
                    Label("Add Card", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingAddCard) {
            CardEditorView(mode: .create(unit))
        }
        .sheet(item: $cardToEdit) { card in
            CardEditorView(mode: .edit(card))
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private func archive(_ card: FlashcardMO) {
        card.isArchived = true
        card.updatedAt = Date()
        do {
            try viewContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func fillMissingAudio() async {
        isFillingAudio = true
        defer {
            isFillingAudio = false
        }

        czyzdSummary = await czyzdAttachmentService.attachMissingAudio(
            in: unit.notebook,
            unit: unit,
            context: viewContext
        )
    }
}
