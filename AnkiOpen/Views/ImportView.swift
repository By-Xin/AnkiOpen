import CoreData
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var notebooks: FetchedResults<NotebookMO>
    @State private var selectedNotebookID: UUID?
    @State private var newNotebookName = ""
    @State private var isCreatingNotebook = false
    @State private var isShowingImporter = false
    @State private var summary: ImportSummary?
    @State private var errorMessage: String?

    private let importer = CSVImporter()

    init() {
        let request = NotebookMO.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NotebookMO.name, ascending: true)]
        _notebooks = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    Toggle("Create new notebook", isOn: $isCreatingNotebook)

                    if isCreatingNotebook {
                        TextField("Notebook name", text: $newNotebookName)
                    } else {
                        Picker("Notebook", selection: $selectedNotebookID) {
                            Text("Select").tag(UUID?.none)
                            ForEach(notebooks) { notebook in
                                Text(notebook.name).tag(Optional(notebook.id))
                            }
                        }
                    }
                }

                Section {
                    Button {
                        isShowingImporter = true
                    } label: {
                        Label("Choose CSV File", systemImage: "doc.badge.plus")
                    }
                    .disabled(!canImport)
                }

                if let summary {
                    Section("Last Import") {
                        LabeledContent("File", value: summary.fileName)
                        LabeledContent("Rows", value: "\(summary.totalRows)")
                        LabeledContent("Imported", value: "\(summary.importedRows)")
                        LabeledContent("Skipped", value: "\(summary.skippedRows)")
                        if let errors = summary.errorsSummary {
                            Text(errors)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Import")
            .onAppear {
                if selectedNotebookID == nil {
                    selectedNotebookID = notebooks.first?.id
                }
            }
            .fileImporter(
                isPresented: $isShowingImporter,
                allowedContentTypes: [.commaSeparatedText, .text],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private var canImport: Bool {
        if isCreatingNotebook {
            return !newNotebookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return selectedNotebookID != nil
    }

    private func destinationNotebook() -> NotebookMO? {
        if isCreatingNotebook {
            let now = Date()
            let notebook = NotebookMO(context: viewContext)
            notebook.id = UUID()
            notebook.name = newNotebookName.trimmingCharacters(in: .whitespacesAndNewlines)
            notebook.createdAt = now
            notebook.updatedAt = now
            return notebook
        }
        return notebooks.first { $0.id == selectedNotebookID }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first, let notebook = destinationNotebook() else {
                return
            }
            summary = try importer.import(url: url, into: notebook, context: viewContext)
            try viewContext.save()
            selectedNotebookID = notebook.id
            isCreatingNotebook = false
            newNotebookName = ""
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
