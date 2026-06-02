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
                Section("导入位置") {
                    Toggle("新建笔记本", isOn: $isCreatingNotebook)

                    if isCreatingNotebook {
                        TextField("笔记本名称", text: $newNotebookName)
                    } else {
                        Picker("笔记本", selection: $selectedNotebookID) {
                            Text("请选择").tag(UUID?.none)
                            ForEach(notebooks) { notebook in
                                Text(notebook.name).tag(Optional(notebook.id))
                            }
                        }
                    }
                }

                Section("CSV 格式") {
                    Label("必填列：front, back", systemImage: "checkmark.seal")
                    Label("单元列：unit", systemImage: "folder")
                    Label("音频列：audio 或 frontAudio/backAudio", systemImage: "speaker.wave.2")
                    Label("词典列：czyzd 或 查词", systemImage: "character.book.closed")
                    Text("也支持中文表头：汉字、读音、单元、音频、查词。单元为空时会导入到默认单元。若 CSV 引用了本地音频，请同时选择音频文件或所在文件夹。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("导入后自动补全潮语词典", isOn: $autoFillCZYZDDictionary)
                        .disabled(isImporting)

                    Toggle("导入后自动匹配潮语音频", isOn: $autoMatchCZYZDAudio)
                        .disabled(isImporting)

                    Button {
                        isShowingImporter = true
                    } label: {
                        Label("选择 CSV 和音频", systemImage: "doc.badge.plus")
                    }
                    .disabled(!hasDestination || isImporting)
                }

                if let preview {
                    Section("预览") {
                        LabeledContent("文件", value: preview.fileName)
                        LabeledContent("目标", value: destinationName)
                        LabeledContent("总行数", value: "\(preview.totalRows)")
                        LabeledContent("将导入", value: "\(preview.importableRows)")
                        LabeledContent("将跳过", value: "\(preview.skippedRows)")
                        LabeledContent("重复", value: "\(preview.duplicateRows)")
                        LabeledContent("词典查询", value: "\(preview.dictionaryLookupRows)")
                        LabeledContent("问题", value: "\(preview.issueCount)")

                        if !preview.units.isEmpty {
                            LabeledContent("单元", value: listed(preview.units))
                        }

                        if !preview.missingAudioFiles.isEmpty {
                            LabeledContent("缺失音频", value: listed(preview.missingAudioFiles))
                        }

                        if !preview.unsupportedAudioFiles.isEmpty {
                            LabeledContent("不支持的音频", value: listed(preview.unsupportedAudioFiles))
                        }

                        if preview.issueCount > 0 {
                            NavigationLink {
                                ImportIssueListView(
                                    title: "预览问题",
                                    sections: previewIssueSections(preview)
                                )
                            } label: {
                                Label("查看问题", systemImage: "exclamationmark.triangle")
                            }
                        }

                        Button {
                            Task {
                                await confirmImport()
                            }
                        } label: {
                            Label(isImporting ? "导入中..." : "导入预览内容", systemImage: "checkmark.circle")
                        }
                        .disabled(!preview.canImport || isImporting)

                        Button(role: .cancel) {
                            clearPendingPreview()
                        } label: {
                            Label("取消预览", systemImage: "xmark.circle")
                        }
                    }
                }

                if let summary {
                    Section("上次导入") {
                        LabeledContent("文件", value: summary.fileName)
                        if let importedNotebook {
                            NavigationLink {
                                NotebookDetailView(notebook: importedNotebook)
                            } label: {
                                Label("打开 \(importedNotebook.name)", systemImage: "books.vertical")
                            }
                        }
                        LabeledContent("总行数", value: "\(summary.totalRows)")
                        LabeledContent("已导入", value: "\(summary.importedRows)")
                        LabeledContent("已跳过", value: "\(summary.skippedRows)")
                        LabeledContent("音频", value: "\(summary.audioFilesImported)")
                        LabeledContent("词典查询", value: "\(summary.dictionaryLookupRows)")
                        LabeledContent("问题", value: "\(summary.issueCount)")
                        if !summary.unitNames.isEmpty {
                            LabeledContent("单元", value: listed(summary.unitNames))
                        }
                        if summary.issueCount > 0 {
                            NavigationLink {
                                ImportIssueListView(
                                    title: "导入问题",
                                    sections: summaryIssueSections(summary)
                                )
                            } label: {
                                Label("查看问题", systemImage: "exclamationmark.triangle")
                            }
                        }
                    }
                }

                if let czyzdSummary {
                    Section("潮语音频") {
                        LabeledContent("检查", value: "\(czyzdSummary.checkedCards)")
                        LabeledContent("匹配", value: "\(czyzdSummary.matchedCards)")
                        LabeledContent("失败", value: "\(czyzdSummary.failedCards)")
                        if let messages = czyzdSummary.messageSummary {
                            Text(messages)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let czyzdDictionarySummary {
                    Section("潮语词典") {
                        LabeledContent("检查", value: "\(czyzdDictionarySummary.checkedCards)")
                        LabeledContent("更新", value: "\(czyzdDictionarySummary.updatedCards)")
                        LabeledContent("失败", value: "\(czyzdDictionarySummary.failedCards)")
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
            .navigationTitle("导入")
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
            .alert("错误", isPresented: .constant(errorMessage != nil), actions: {
                Button("好的") { errorMessage = nil }
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
        return existingDestinationNotebook()?.name ?? "请选择"
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
                errorMessage = "请选择一个 CSV 文件，以及 CSV 引用到的音频文件。"
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
                errorMessage = "请先选择 CSV 文件和导入位置。"
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
        let suffix = values.count > limit ? " +\(values.count - limit) 个" : ""
        return visibleValues.joined(separator: ", ") + suffix
    }

    private func previewIssueSections(_ preview: ImportPreview) -> [ImportIssueSection] {
        [
            ImportIssueSection(title: "跳过的行", systemImage: "forward.end", items: preview.skippedRowDetails),
            ImportIssueSection(title: "行错误", systemImage: "exclamationmark.triangle", items: preview.errors),
            ImportIssueSection(title: "音频", systemImage: "speaker.wave.2", items: preview.audioWarnings),
            ImportIssueSection(title: "生僻字", systemImage: "textformat.alt", items: preview.glyphWarnings)
        ].filter { !$0.items.isEmpty }
    }

    private func summaryIssueSections(_ summary: ImportSummary) -> [ImportIssueSection] {
        [
            ImportIssueSection(title: "跳过的行", systemImage: "forward.end", items: summary.skippedRowDetails),
            ImportIssueSection(title: "导入错误", systemImage: "exclamationmark.triangle", items: summary.errors),
            ImportIssueSection(title: "生僻字", systemImage: "textformat.alt", items: summary.glyphWarnings)
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
