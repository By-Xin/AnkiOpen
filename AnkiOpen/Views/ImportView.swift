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
                    Text("CSV columns: front, back, optional unit, optional audio/frontAudio/backAudio. Blank unit values import into Default.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

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
                        LabeledContent("Audio", value: "\(summary.audioFilesImported)")
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
                allowedContentTypes: [.commaSeparatedText, .text, .audio],
                allowsMultipleSelection: true
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
            guard let csvURL = csvURL(from: urls), let notebook = destinationNotebook() else {
                errorMessage = "Select one CSV file and any referenced audio files."
                return
            }
            let mediaURLs = urls.filter { AudioFileStore.isSupportedAudioFile($0) }
            summary = try importer.import(url: csvURL, into: notebook, context: viewContext, mediaURLs: mediaURLs)
            try viewContext.save()
            selectedNotebookID = notebook.id
            isCreatingNotebook = false
            newNotebookName = ""
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func csvURL(from urls: [URL]) -> URL? {
        urls.first {
            ["csv", "txt"].contains($0.pathExtension.lowercased())
        }
    }
}
