import CoreData
import SwiftUI

struct NotebookDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var notebook: NotebookMO
    @FetchRequest private var cards: FetchedResults<FlashcardMO>
    @State private var searchText = ""
    @State private var isShowingAddCard = false
    @State private var cardToEdit: FlashcardMO?
    @State private var errorMessage: String?

    init(notebook: NotebookMO) {
        self.notebook = notebook
        let request = FlashcardMO.fetchRequest()
        request.predicate = NSPredicate(format: "notebook == %@ AND isArchived == NO", notebook)
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
                    StudyView(initialNotebook: notebook)
                } label: {
                    Label("Study Due Cards", systemImage: "rectangle.stack.badge.play")
                }
            }

            Section("Cards") {
                ForEach(filteredCards) { card in
                    Button {
                        cardToEdit = card
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(card.front)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(card.back)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
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
                    message: "Add a card or import a CSV into this notebook."
                )
            }
        }
        .navigationTitle(notebook.name)
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
            CardEditorView(mode: .create(notebook))
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
}
