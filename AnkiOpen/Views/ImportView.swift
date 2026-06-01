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
    @State private var czyzdSummary: CZYZDAudioAttachmentSummary?
    @State private var importedNotebook: NotebookMO?
    @State private var errorMessage: String?
    @State private var autoMatchCZYZDAudio = true
    @State private var isImporting = false

    private let importer = CSVImporter()
    private let czyzdAttachmentService = CZYZDAudioAttachmentService()

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

                Section("CSV Format") {
                    LabeledContent("Required", value: "front, back")
                    LabeledContent("Units", value: "unit")
                    LabeledContent("Audio", value: "audio or frontAudio/backAudio")
                    Text("Chinese headers are supported: 汉字, 读音, 单元, 音频. Empty unit values import into Default. Select referenced audio files or the folder that contains them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Auto-match CZYZD audio after import", isOn: $autoMatchCZYZDAudio)
                        .disabled(isImporting)

                    Button {
                        isShowingImporter = true
                    } label: {
                        Label("Choose CSV and Audio", systemImage: "doc.badge.plus")
                    }
                    .disabled(!hasDestination || isImporting)
                }

                if let preview {
                    Section("Preview") {
                        LabeledContent("File", value: preview.fileName)
                        LabeledContent("Destination", value: destinationName)
                        LabeledContent("Rows", value: "\(preview.totalRows)")
                        LabeledContent("Will import", value: "\(preview.importableRows)")
                        LabeledContent("Will skip", value: "\(preview.skippedRows)")
                        LabeledContent("Duplicates", value: "\(preview.duplicateRows)")
                        LabeledContent("Warnings", value: "\(preview.audioWarnings.count + preview.glyphWarnings.count)")

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
                            Label("Rows needing fixes", systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                            Text(errors)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let warnings = preview.audioWarningsSummary {
                            Text(warnings)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let warnings = preview.glyphWarningsSummary {
                            Label("Glyph warnings", systemImage: "textformat.alt")
                                .font(.subheadline)
                            Text(warnings)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            Task {
                                await confirmImport()
                            }
                        } label: {
                            Label(isImporting ? "Importing..." : "Import Previewed Rows", systemImage: "checkmark.circle")
                        }
                        .disabled(!preview.canImport || isImporting)

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
                        if let importedNotebook {
                            NavigationLink {
                                NotebookDetailView(notebook: importedNotebook)
                            } label: {
                                Label("Open \(importedNotebook.name)", systemImage: "books.vertical")
                            }
                        }
                        LabeledContent("Rows", value: "\(summary.totalRows)")
                        LabeledContent("Imported", value: "\(summary.importedRows)")
                        LabeledContent("Skipped", value: "\(summary.skippedRows)")
                        LabeledContent("Audio", value: "\(summary.audioFilesImported)")
                        if !summary.unitNames.isEmpty {
                            LabeledContent("Units", value: listed(summary.unitNames))
                        }
                        if let errors = summary.errorsSummary {
                            Text(errors)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let warnings = summary.glyphWarningsSummary {
                            Label("Glyph warnings", systemImage: "textformat.alt")
                                .font(.subheadline)
                            Text(warnings)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
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
                allowedContentTypes: [.commaSeparatedText, .text, .audio, .folder],
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

    private var destinationName: String {
        if isCreatingNotebook {
            return newNotebookName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return existingDestinationNotebook()?.name ?? "Select"
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
            czyzdSummary = nil
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

    @MainActor
    private func confirmImport() async {
        isImporting = true
        defer {
            isImporting = false
        }

        do {
            guard let csvURL = pendingCSVURL, let notebook = destinationNotebook() else {
                errorMessage = "Choose a CSV file and destination before importing."
                return
            }

            let importSummary = try importer.import(url: csvURL, into: notebook, context: viewContext, mediaURLs: pendingMediaURLs)
            summary = importSummary
            try viewContext.save()
            importedNotebook = notebook
            selectedNotebookID = notebook.id
            isCreatingNotebook = false
            newNotebookName = ""
            clearPendingPreview()

            if autoMatchCZYZDAudio {
                czyzdSummary = await czyzdAttachmentService.attachMissingAudio(
                    toImportedCardIDs: importSummary.importedCardIDs,
                    context: viewContext
                )
            }
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
