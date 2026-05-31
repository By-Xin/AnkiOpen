import CoreData
import SwiftUI

struct NotebookDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var notebook: NotebookMO
    @FetchRequest private var units: FetchedResults<NotebookUnitMO>
    @State private var isShowingAddUnit = false
    @State private var unitToEdit: NotebookUnitMO?
    @State private var errorMessage: String?

    init(notebook: NotebookMO) {
        self.notebook = notebook
        let request = NotebookUnitMO.fetchRequest()
        request.predicate = NSPredicate(format: "notebook == %@", notebook)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \NotebookUnitMO.sortIndex, ascending: true),
            NSSortDescriptor(keyPath: \NotebookUnitMO.createdAt, ascending: true)
        ]
        _units = FetchRequest(fetchRequest: request, animation: .default)
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

            Section("Units") {
                ForEach(units) { unit in
                    NavigationLink {
                        UnitDetailView(unit: unit)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(unit.name)
                                .font(.headline)
                            Text("\(unit.activeCardsCount) cards")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            unitToEdit = unit
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(unit)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .overlay {
            if units.isEmpty {
                EmptyStateView(
                    title: "No Units",
                    systemImage: "folder",
                    message: "Create a unit or import a CSV into this notebook."
                )
            }
        }
        .navigationTitle(notebook.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddUnit = true
                } label: {
                    Label("Add Unit", systemImage: "plus")
                }
            }
        }
        .onAppear(perform: ensureDefaultUnitsForLegacyCards)
        .sheet(isPresented: $isShowingAddUnit) {
            UnitEditorView(mode: .create(notebook))
        }
        .sheet(item: $unitToEdit) { unit in
            UnitEditorView(mode: .edit(unit))
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private func delete(_ unit: NotebookUnitMO) {
        viewContext.delete(unit)
        do {
            try viewContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ensureDefaultUnitsForLegacyCards() {
        let orphanedCards = notebook.flashcards.filter { $0.unit == nil }
        guard !orphanedCards.isEmpty else {
            return
        }

        let defaultUnit = NotebookUnitMO.findOrCreateDefault(in: notebook, context: viewContext)
        orphanedCards.forEach { $0.unit = defaultUnit }
        do {
            try viewContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
