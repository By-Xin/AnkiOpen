import CoreData
import SwiftUI

struct StudyView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var notebooks: FetchedResults<NotebookMO>
    @State private var selectedNotebook: NotebookMO?
    @State private var dueCards: [FlashcardMO] = []
    @State private var currentIndex = 0
    @State private var isShowingBack = false
    @State private var errorMessage: String?

    private let scheduler = ReviewScheduler()

    init(initialNotebook: NotebookMO? = nil) {
        _selectedNotebook = State(initialValue: initialNotebook)
        let request = NotebookMO.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NotebookMO.name, ascending: true)]
        _notebooks = FetchRequest(fetchRequest: request, animation: .default)
    }

    private var currentCard: FlashcardMO? {
        guard dueCards.indices.contains(currentIndex) else {
            return nil
        }
        return dueCards[currentIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Notebook", selection: notebookSelection) {
                    Text("All Notebooks").tag(UUID?.none)
                    ForEach(notebooks) { notebook in
                        Text(notebook.name).tag(Optional(notebook.id))
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)

                if let card = currentCard {
                    VStack(spacing: 18) {
                        Text("\(currentIndex + 1) of \(dueCards.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {
                            withAnimation(.easeInOut) {
                                isShowingBack.toggle()
                            }
                        } label: {
                            VStack(spacing: 18) {
                                Text(isShowingBack ? "Back" : "Front")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(isShowingBack ? card.back : card.front)
                                    .font(.title2)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, minHeight: 220)
                            }
                            .padding(24)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)

                        if isShowingBack {
                            HStack(spacing: 10) {
                                ForEach(ReviewRating.allCases) { rating in
                                    Button(rating.title) {
                                        review(card, rating: rating)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            Button {
                                withAnimation(.easeInOut) {
                                    isShowingBack = true
                                }
                            } label: {
                                Label("Show Answer", systemImage: "eye")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    EmptyStateView(
                        title: "No Due Cards",
                        systemImage: "checkmark.circle",
                        message: "You are caught up for now."
                    )
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("Study")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        reloadDueCards()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .onAppear(perform: reloadDueCards)
            .onChange(of: selectedNotebook?.id) { _ in
                reloadDueCards()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private var notebookSelection: Binding<UUID?> {
        Binding {
            selectedNotebook?.id
        } set: { id in
            selectedNotebook = notebooks.first { $0.id == id }
        }
    }

    private func reloadDueCards() {
        do {
            dueCards = try DueCardQuery.forNotebook(selectedNotebook, at: Date(), context: viewContext)
            currentIndex = 0
            isShowingBack = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func review(_ card: FlashcardMO, rating: ReviewRating) {
        do {
            _ = try scheduler.review(card: card, rating: rating, reviewedAt: Date(), context: viewContext)
            try viewContext.save()
            dueCards.removeAll { $0.objectID == card.objectID }
            currentIndex = min(currentIndex, max(0, dueCards.count - 1))
            isShowingBack = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
