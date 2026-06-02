import CoreData
import SwiftUI

struct NotebooksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var notebooks: FetchedResults<NotebookMO>
    @State private var isShowingAddNotebook = false
    @State private var notebookToEdit: NotebookMO?
    @State private var errorMessage: String?

    init() {
        let request = NotebookMO.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NotebookMO.updatedAt, ascending: false)]
        _notebooks = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(notebooks) { notebook in
                    NavigationLink {
                        NotebookDetailView(notebook: notebook)
                    } label: {
                        HStack(spacing: 12) {
                            LeadingSymbol(systemImage: "books.vertical")
                            VStack(alignment: .leading, spacing: 6) {
                                Text(notebook.name)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppPalette.ink)
                                Text("Updated \(notebook.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 12)
                            MetricPill(value: "\(notebook.unitsCount)", label: "units")
                            MetricPill(value: "\(notebook.activeCardsCount)", label: "cards", tint: AppPalette.amber)
                        }
                    }
                    .appListRow()
                    .swipeActions(edge: .leading) {
                        Button {
                            notebookToEdit = notebook
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
            .overlay {
                if notebooks.isEmpty {
                    EmptyStateView(
                        title: "No Notebooks",
                        systemImage: "books.vertical",
                        message: "Create a notebook or import a CSV to begin."
                    )
                }
            }
            .navigationTitle("Notebooks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddNotebook = true
                    } label: {
                        Label("Add Notebook", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddNotebook) {
                NotebookEditorView(mode: .create)
            }
            .sheet(item: $notebookToEdit) { notebook in
                NotebookEditorView(mode: .edit(notebook))
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private func delete(offsets: IndexSet) {
        offsets.map { notebooks[$0] }.forEach(viewContext.delete)
        do {
            try viewContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
