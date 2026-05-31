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
    @State private var pendingCSVURL: URL?
    @State private var pendingMediaURLs: [URL] = []
    @State private var preview: ImportPreview?
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
                        Label("Choose CSV and Audio Files", systemImage: "doc.badge.plus")
                    }
                    .disabled(!hasDestination)
                }

                if let preview {
                    Section("Preview") {
                        LabeledContent("File", value: preview.fileName)
                        LabeledContent("Rows", value: "\(preview.totalRows)")
                        LabeledContent("Will import", value: "\(preview.importableRows)")
                        LabeledContent("Will skip", value: "\(preview.skippedRows)")
                        LabeledContent("Duplicates", value: "\(preview.duplicateRows)")

                        if !preview.units.isEmpty {
                            LabeledContent("Units", value: listed(preview.units))
                        }

                        if !preview.missingAudioFiles.isEmpty {
                            LabeledContent("Missing audio", value: listed(preview.missingAudioFiles))
                        }

                        if !preview.unsupportedAudioFiles.isEmpty {
                            LabeledContent("Unsupported audio", value: listed(preview.unsupportedAudioFiles))
                        }

                        if let errors = preview.errorsSummary {
                            Text(errors)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let warnings = preview.audioWarningsSummary {
                            Text(warnings)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            confirmImport()
                        } label: {
                            Label("Import Previewed Rows", systemImage: "checkmark.circle")
                        }
                        .disabled(!preview.canImport)

                        Button(role: .cancel) {
                            clearPendingPreview()
                        } label: {
                            Label("Cancel Preview", systemImage: "xmark.circle")
                        }
                    }
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
            .onChange(of: selectedNotebookID) { _ in
                clearPendingPreview()
            }
            .onChange(of: isCreatingNotebook) { _ in
                clearPendingPreview()
            }
            .onChange(of: newNotebookName) { _ in
                clearPendingPreview()
            }
            .fileImporter(
                isPresented: $isShowingImporter,
                allowedContentTypes: [.commaSeparatedText, .text, .audio],
                allowsMultipleSelection: true
            ) { result in
                handleFileSelection(result)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private var hasDestination: Bool {
        if isCreatingNotebook {
            return !newNotebookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return existingDestinationNotebook() != nil
    }

    private func existingDestinationNotebook() -> NotebookMO? {
        notebooks.first { $0.id == selectedNotebookID }
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
        return existingDestinationNotebook()
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard hasDestination, let csvURL = csvURL(from: urls) else {
                errorMessage = "Select one CSV file and any referenced audio files."
                return
            }

            let mediaURLs = urls.filter { $0 != csvURL }
            pendingCSVURL = csvURL
            pendingMediaURLs = mediaURLs
            preview = try importer.preview(
                url: csvURL,
                into: isCreatingNotebook ? nil : existingDestinationNotebook(),
                context: viewContext,
                mediaURLs: mediaURLs
            )
        } catch {
            clearPendingPreview()
            errorMessage = error.localizedDescription
        }
    }

    private func confirmImport() {
        do {
            guard let csvURL = pendingCSVURL, let notebook = destinationNotebook() else {
                errorMessage = "Choose a CSV file and destination before importing."
                return
            }

            summary = try importer.import(url: csvURL, into: notebook, context: viewContext, mediaURLs: pendingMediaURLs)
            try viewContext.save()
            selectedNotebookID = notebook.id
            isCreatingNotebook = false
            newNotebookName = ""
            clearPendingPreview()
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func clearPendingPreview() {
        pendingCSVURL = nil
        pendingMediaURLs = []
        preview = nil
    }

    private func csvURL(from urls: [URL]) -> URL? {
        urls.first {
            ["csv", "txt"].contains($0.pathExtension.lowercased())
        }
    }

    private func listed(_ values: [String], limit: Int = 8) -> String {
        let visibleValues = values.prefix(limit)
        let suffix = values.count > limit ? " +\(values.count - limit) more" : ""
        return visibleValues.joined(separator: ", ") + suffix
    }
}
