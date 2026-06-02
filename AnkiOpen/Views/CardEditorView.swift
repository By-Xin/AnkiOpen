import SwiftUI

struct CardEditorView: View {
    enum Mode {
        case create(NotebookUnitMO)
        case createInNotebook(NotebookMO)
        case edit(FlashcardMO)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    let mode: Mode
    @State private var front: String
    @State private var back: String
    @State private var errorMessage: String?
    @State private var dictionaryStatusMessage: String?
    @State private var isLookingUpDictionary = false
    @State private var pendingDictionaryBackText: String?
    @State private var isConfirmingDictionaryOverwrite = false
    @State private var audioStatusMessage: String?
    @State private var isMatchingAudio = false
    @State private var pendingAudioDownload: CZYZDAudioDownload?
    @State private var isShowingReport = false

    private let dictionaryLookup: CZYZDDictionaryLookingUp
    private let audioResolver: CZYZDAudioResolving

    init(
        mode: Mode,
        dictionaryLookup: CZYZDDictionaryLookingUp = CZYZDDictionaryLookup(),
        audioResolver: CZYZDAudioResolving = CZYZDAudioResolver()
    ) {
        self.mode = mode
        self.dictionaryLookup = dictionaryLookup
        self.audioResolver = audioResolver
        switch mode {
        case .create, .createInNotebook:
            _front = State(initialValue: "")
            _back = State(initialValue: "")
        case .edit(let card):
            _front = State(initialValue: card.front)
            _back = State(initialValue: card.back)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("正面") {
                    TextEditor(text: $front)
                        .flashcardCJKFont(size: 17, relativeTo: .body)
                        .frame(minHeight: 110)
                    if let warning = GlyphDiagnostics.warningSummary(for: front) {
                        Label("可能含有生僻字", systemImage: "textformat.alt")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text(warning)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("背面") {
                    TextEditor(text: $back)
                        .flashcardCJKFont(size: 17, relativeTo: .body)
                        .frame(minHeight: 110)
                    if let warning = GlyphDiagnostics.warningSummary(for: back) {
                        Label("可能含有生僻字", systemImage: "textformat.alt")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text(warning)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("潮语词典") {
                    Button {
                        Task {
                            await fillBackFromDictionary()
                        }
                    } label: {
                        Label(isLookingUpDictionary ? "正在查词..." : "按正面查词填充背面", systemImage: "book")
                    }
                    .disabled(front.trimmed.isEmpty || isLookingUpDictionary)

                    Button {
                        Task {
                            await matchAudioFromDictionary()
                        }
                    } label: {
                        Label(isMatchingAudio ? "正在匹配音频..." : "按正面匹配音频", systemImage: "speaker.wave.2")
                    }
                    .disabled(front.trimmed.isEmpty || isMatchingAudio)

                    if let dictionaryStatusMessage {
                        Text(dictionaryStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let audioStatusMessage {
                        Text(audioStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if let currentAudioSummary {
                        Text(currentAudioSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("会用正面文字查询潮语词典，并把结果整理为“潮拼”和“解释”；匹配到的音频会在保存时应用到正反两面。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if editableCard != nil {
                    Section("反馈") {
                        Button {
                            isShowingReport = true
                        } label: {
                            Label("反馈卡片问题", systemImage: "exclamationmark.bubble")
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(front.trimmed.isEmpty || back.trimmed.isEmpty)
                }
            }
            .alert("错误", isPresented: .constant(errorMessage != nil), actions: {
                Button("好的") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
            .confirmationDialog("背面已有内容", isPresented: $isConfirmingDictionaryOverwrite, titleVisibility: .visible) {
                Button("覆盖背面") {
                    applyPendingDictionaryBackText()
                }
                Button("取消", role: .cancel) {
                    pendingDictionaryBackText = nil
                }
            } message: {
                Text("是否用潮语词典结果覆盖当前背面？")
            }
            .sheet(isPresented: $isShowingReport) {
                if let card = editableCard {
                    ReportIssueView(card: card)
                }
            }
        }
    }

    private var title: String {
        switch mode {
        case .create, .createInNotebook: return "新建卡片"
        case .edit: return "编辑卡片"
        }
    }

    private var editableCard: FlashcardMO? {
        if case .edit(let card) = mode {
            return card
        }
        return nil
    }

    private func save() {
        let storedAudioFileName: String?
        do {
            storedAudioFileName = try storePendingAudioIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let now = Date()
        switch mode {
        case .create(let unit):
            _ = FlashcardMO.insert(
                front: front.trimmed,
                back: back.trimmed,
                unit: unit,
                context: viewContext,
                frontAudioFileName: storedAudioFileName,
                backAudioFileName: storedAudioFileName
            )
            unit.updatedAt = now
            unit.notebook.updatedAt = now
        case .createInNotebook(let notebook):
            _ = FlashcardMO.insert(
                front: front.trimmed,
                back: back.trimmed,
                notebook: notebook,
                context: viewContext,
                frontAudioFileName: storedAudioFileName,
                backAudioFileName: storedAudioFileName
            )
            notebook.updatedAt = now
        case .edit(let card):
            card.front = front.trimmed
            card.back = back.trimmed
            if let storedAudioFileName {
                card.frontAudioFileName = storedAudioFileName
                card.backAudioFileName = storedAudioFileName
            }
            card.updatedAt = now
            card.unit?.updatedAt = now
            card.notebook.updatedAt = now
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func fillBackFromDictionary() async {
        let term = front.trimmed
        guard !term.isEmpty else {
            return
        }

        isLookingUpDictionary = true
        dictionaryStatusMessage = nil
        defer {
            isLookingUpDictionary = false
        }

        do {
            guard let entry = try await dictionaryLookup.lookup(term: term).first else {
                dictionaryStatusMessage = "没有找到“\(term)”的词典结果。"
                return
            }

            let dictionaryBackText = CZYZDDictionaryNotebookBuilder.cardBackText(from: entry)
            guard !dictionaryBackText.isEmpty else {
                dictionaryStatusMessage = "找到“\(term)”，但没有可用的潮拼或解释。"
                return
            }

            pendingDictionaryBackText = dictionaryBackText
            if back.trimmed.isEmpty {
                applyPendingDictionaryBackText()
            } else {
                isConfirmingDictionaryOverwrite = true
            }
        } catch {
            dictionaryStatusMessage = error.localizedDescription
        }
    }

    private func applyPendingDictionaryBackText() {
        guard let pendingDictionaryBackText else {
            return
        }
        back = pendingDictionaryBackText
        dictionaryStatusMessage = "已填充潮语词典结果。"
        self.pendingDictionaryBackText = nil
    }

    @MainActor
    private func matchAudioFromDictionary() async {
        let term = front.trimmed
        guard !term.isEmpty else {
            return
        }

        isMatchingAudio = true
        audioStatusMessage = nil
        defer {
            isMatchingAudio = false
        }

        do {
            guard let download = try await audioResolver.downloadAudio(for: term) else {
                pendingAudioDownload = nil
                audioStatusMessage = "没有找到“\(term)”的 CZYZD 音频。"
                return
            }

            pendingAudioDownload = download
            audioStatusMessage = "已匹配 \(download.suggestedFileName)，保存后会应用到正反两面。"
        } catch {
            audioStatusMessage = error.localizedDescription
        }
    }

    private var currentAudioSummary: String? {
        guard let card = editableCard else {
            return nil
        }

        switch (card.frontAudioFileName, card.backAudioFileName) {
        case (.some, .some):
            return "当前卡片正反两面已有音频。"
        case (.some, .none):
            return "当前卡片正面已有音频。"
        case (.none, .some):
            return "当前卡片背面已有音频。"
        case (.none, .none):
            return nil
        }
    }

    private func storePendingAudioIfNeeded() throws -> String? {
        guard let pendingAudioDownload else {
            return nil
        }

        return try AudioFileStore.storeDownloadedAudio(
            data: pendingAudioDownload.data,
            suggestedFileName: pendingAudioDownload.suggestedFileName
        )
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
