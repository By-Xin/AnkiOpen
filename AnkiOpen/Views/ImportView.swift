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
    @State private var czyzdDictionarySummary: CZYZDDictionaryEnrichmentSummary?
    @State private var importedNotebook: NotebookMO?
    @State private var errorMessage: String?
    @State private var autoMatchCZYZDAudio = true
    @State private var autoFillCZYZDDictionary = true
    @State private var isImporting = false

    private let importer = CSVImporter()
    private let czyzdAttachmentService = CZYZDAudioAttachmentService()
    private let czyzdDictionaryService = CZYZDDictionaryEnrichmentService()

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
                    Label("Required: front, back", systemImage: "checkmark.seal")
                    Label("Units: unit", systemImage: "folder")
                    Label("Audio: audio or frontAudio/backAudio", systemImage: "speaker.wave.2")
                    Label("Dictionary: czyzd or 查词", systemImage: "character.book.closed")
                    Text("Chinese headers are supported: 汉字, 读音, 单元, 音频, 查词. Empty unit values import into Default. Select referenced audio files or the folder that contains them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Auto-fill CZYZD dictionary after import", isOn: $autoFillCZYZDDictionary)
                        .disabled(isImporting)

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
                        LabeledContent("Dictionary lookups", value: "\(preview.dictionaryLookupRows)")
                        LabeledContent("Issues", value: "\(preview.issueCount)")

                        if !preview.units.isEmpty {
                            LabeledContent("Units", value: listed(preview.units))
                        }

                        if !preview.missingAudioFiles.isEmpty {
                            LabeledContent("Missing audio", value: listed(preview.missingAudioFiles))
                        }

                        if !preview.unsupportedAudioFiles.isEmpty {
                            LabeledContent("Unsupported audio", value: listed(preview.unsupportedAudioFiles))
                        }

                        if preview.issueCount > 0 {
                            NavigationLink {
                                ImportIssueListView(
                                    title: "Preview Issues",
                                    sections: previewIssueSections(preview)
                                )
                            } label: {
                                Label("Review Issues", systemImage: "exclamationmark.triangle")
                            }
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
                        LabeledContent("Dictionary lookups", value: "\(summary.dictionaryLookupRows)")
                        LabeledContent("Issues", value: "\(summary.issueCount)")
                        if !summary.unitNames.isEmpty {
                            LabeledContent("Units", value: listed(summary.unitNames))
                        }
                        if summary.issueCount > 0 {
                            NavigationLink {
                                ImportIssueListView(
                                    title: "Import Issues",
                                    sections: summaryIssueSections(summary)
                                )
                            } label: {
                                Label("Review Issues", systemImage: "exclamationmark.triangle")
                            }
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

                if let czyzdDictionarySummary {
                    Section("CZYZD Dictionary") {
                        LabeledContent("Checked", value: "\(czyzdDictionarySummary.checkedCards)")
                        LabeledContent("Updated", value: "\(czyzdDictionarySummary.updatedCards)")
                        LabeledContent("Failed", value: "\(czyzdDictionarySummary.failedCards)")
                        if let messages = czyzdDictionarySummary.messageSummary {
                            Text(messages)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppPalette.paper.ignoresSafeArea())
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
            czyzdDictionarySummary = nil
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

            if autoFillCZYZDDictionary {
                czyzdDictionarySummary = await czyzdDictionaryService.enrichImportedCards(
                    lookupTermsByCardID: importSummary.dictionaryLookupTermsByCardID,
                    context: viewContext
                )
                try viewContext.save()
            }

            if autoMatchCZYZDAudio {
                czyzdSummary = await czyzdAttachmentService.attachMissingAudio(
                    toImportedCardIDs: importSummary.importedCardIDs,
                    context: viewContext
                )
                try viewContext.save()
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

    private func previewIssueSections(_ preview: ImportPreview) -> [ImportIssueSection] {
        [
            ImportIssueSection(title: "Skipped Rows", systemImage: "forward.end", items: preview.skippedRowDetails),
            ImportIssueSection(title: "Row Errors", systemImage: "exclamationmark.triangle", items: preview.errors),
            ImportIssueSection(title: "Audio", systemImage: "speaker.wave.2", items: preview.audioWarnings),
            ImportIssueSection(title: "Glyphs", systemImage: "textformat.alt", items: preview.glyphWarnings)
        ].filter { !$0.items.isEmpty }
    }

    private func summaryIssueSections(_ summary: ImportSummary) -> [ImportIssueSection] {
        [
            ImportIssueSection(title: "Skipped Rows", systemImage: "forward.end", items: summary.skippedRowDetails),
            ImportIssueSection(title: "Import Errors", systemImage: "exclamationmark.triangle", items: summary.errors),
            ImportIssueSection(title: "Glyphs", systemImage: "textformat.alt", items: summary.glyphWarnings)
        ].filter { !$0.items.isEmpty }
    }
}

private struct ImportIssueSection: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let items: [String]
}

private struct ImportIssueListView: View {
    let title: String
    let sections: [ImportIssueSection]

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                        Text(item)
                            .font(.footnote)
                    }
                } header: {
                    Label(section.title, systemImage: section.systemImage)
                }
            }
        }
        .navigationTitle(title)
    }
}
