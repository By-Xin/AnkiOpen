import SwiftUI
import UniformTypeIdentifiers

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
    @State private var isShowingAudioImporter = false
    @State private var audioImportTarget: AudioImportTarget?
    @State private var pendingFrontAudio: PendingAudioAttachment?
    @State private var pendingBackAudio: PendingAudioAttachment?
    @State private var shouldRemoveFrontAudio = false
    @State private var shouldRemoveBackAudio = false
    @StateObject private var audioPlayer = AudioPlaybackController()

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

                Section("音频") {
                    if let pendingAudioDownload, (!shouldRemoveFrontAudio || !shouldRemoveBackAudio) {
                        LabeledContent("词典待保存", value: pendingAudioDownload.suggestedFileName)

                        Button {
                            _ = audioPlayer.play(data: pendingAudioDownload.data)
                        } label: {
                            Label("试听词典匹配音频", systemImage: "speaker.wave.2")
                        }

                        Text("保存后会替换为正反两面共用的本地音频。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let pendingFrontAudio {
                        pendingAudioRow(title: "待保存正面", attachment: pendingFrontAudio)
                    } else if shouldRemoveFrontAudio {
                        Label("保存后移除正面音频", systemImage: "minus.circle")
                            .foregroundStyle(.secondary)
                    }

                    if let pendingBackAudio {
                        pendingAudioRow(title: "待保存背面", attachment: pendingBackAudio)
                    } else if shouldRemoveBackAudio {
                        Label("保存后移除背面音频", systemImage: "minus.circle")
                            .foregroundStyle(.secondary)
                    }

                    if let card = editableCard {
                        if !shouldRemoveFrontAudio, let frontAudioFileName = card.frontAudioFileName {
                            Button {
                                _ = audioPlayer.play(storedFileName: frontAudioFileName)
                            } label: {
                                Label("试听当前正面音频", systemImage: "speaker.wave.2")
                            }
                        }

                        if !shouldRemoveBackAudio, let backAudioFileName = card.backAudioFileName {
                            Button {
                                _ = audioPlayer.play(storedFileName: backAudioFileName)
                            } label: {
                                Label("试听当前背面音频", systemImage: "speaker.wave.2")
                            }
                        }
                    }

                    Button {
                        beginAudioImport(for: .front)
                    } label: {
                        Label("选择正面音频", systemImage: "speaker.wave.2")
                    }

                    Button {
                        beginAudioImport(for: .back)
                    } label: {
                        Label("选择背面音频", systemImage: "speaker.wave.2")
                    }

                    Button {
                        beginAudioImport(for: .both)
                    } label: {
                        Label("选择共用音频", systemImage: "speaker.wave.2.fill")
                    }

                    if hasFrontAudioCandidate || hasBackAudioCandidate {
                        Button(role: .destructive) {
                            removeFrontAudio()
                        } label: {
                            Label("移除正面音频", systemImage: "minus.circle")
                        }
                        .disabled(!hasFrontAudioCandidate)

                        Button(role: .destructive) {
                            removeBackAudio()
                        } label: {
                            Label("移除背面音频", systemImage: "minus.circle")
                        }
                        .disabled(!hasBackAudioCandidate)

                        Button(role: .destructive) {
                            removeAllAudio()
                        } label: {
                            Label("移除全部音频", systemImage: "speaker.slash")
                        }
                    }

                    if !hasFrontAudioCandidate, !hasBackAudioCandidate {
                        Text("暂无音频。可以先用“按正面匹配音频”从潮语词典查找。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
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
            .fileImporter(
                isPresented: $isShowingAudioImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                handleAudioSelection(result)
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
        let storedSharedAudioFileName: String?
        let storedFrontAudioFileName: String?
        let storedBackAudioFileName: String?
        do {
            storedSharedAudioFileName = try storePendingAudioIfNeeded()
            (storedFrontAudioFileName, storedBackAudioFileName) = try storePendingManualAudioIfNeeded()
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
                frontAudioFileName: finalFrontAudioFileName(
                    existing: nil,
                    shared: storedSharedAudioFileName,
                    manual: storedFrontAudioFileName
                ),
                backAudioFileName: finalBackAudioFileName(
                    existing: nil,
                    shared: storedSharedAudioFileName,
                    manual: storedBackAudioFileName
                )
            )
            unit.updatedAt = now
            unit.notebook.updatedAt = now
        case .createInNotebook(let notebook):
            _ = FlashcardMO.insert(
                front: front.trimmed,
                back: back.trimmed,
                notebook: notebook,
                context: viewContext,
                frontAudioFileName: finalFrontAudioFileName(
                    existing: nil,
                    shared: storedSharedAudioFileName,
                    manual: storedFrontAudioFileName
                ),
                backAudioFileName: finalBackAudioFileName(
                    existing: nil,
                    shared: storedSharedAudioFileName,
                    manual: storedBackAudioFileName
                )
            )
            notebook.updatedAt = now
        case .edit(let card):
            card.front = front.trimmed
            card.back = back.trimmed
            card.frontAudioFileName = finalFrontAudioFileName(
                existing: card.frontAudioFileName,
                shared: storedSharedAudioFileName,
                manual: storedFrontAudioFileName
            )
            card.backAudioFileName = finalBackAudioFileName(
                existing: card.backAudioFileName,
                shared: storedSharedAudioFileName,
                manual: storedBackAudioFileName
            )
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
            pendingFrontAudio = nil
            pendingBackAudio = nil
            shouldRemoveFrontAudio = false
            shouldRemoveBackAudio = false
            audioStatusMessage = "已匹配 \(download.suggestedFileName)，保存后会应用到正反两面。"
        } catch {
            audioStatusMessage = error.localizedDescription
        }
    }

    private func pendingAudioRow(title: String, attachment: PendingAudioAttachment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(title, value: attachment.suggestedFileName)
            Button {
                _ = audioPlayer.play(data: attachment.data)
            } label: {
                Label("试听\(title)", systemImage: "speaker.wave.2")
            }
        }
    }

    private func beginAudioImport(for target: AudioImportTarget) {
        audioImportTarget = target
        isShowingAudioImporter = true
    }

    private func handleAudioSelection(_ result: Result<[URL], Error>) {
        do {
            guard let target = audioImportTarget else {
                return
            }
            guard let url = try result.get().first else {
                return
            }

            let attachment = try pendingAudioAttachment(from: url)
            switch target {
            case .front:
                pendingFrontAudio = attachment
                shouldRemoveFrontAudio = false
                audioStatusMessage = "已选择正面音频，保存后生效。"
            case .back:
                pendingBackAudio = attachment
                shouldRemoveBackAudio = false
                audioStatusMessage = "已选择背面音频，保存后生效。"
            case .both:
                pendingAudioDownload = nil
                pendingFrontAudio = attachment
                pendingBackAudio = attachment
                shouldRemoveFrontAudio = false
                shouldRemoveBackAudio = false
                audioStatusMessage = "已选择共用音频，保存后应用到正反两面。"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        audioImportTarget = nil
    }

    private func pendingAudioAttachment(from url: URL) throws -> PendingAudioAttachment {
        let fileName = url.lastPathComponent
        guard AudioFileStore.isSupportedAudioFile(url) else {
            throw AudioFileStoreError.unsupportedFormat(fileName)
        }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return PendingAudioAttachment(
            data: try Data(contentsOf: url),
            suggestedFileName: fileName
        )
    }

    private func removeFrontAudio() {
        pendingAudioDownload = nil
        pendingFrontAudio = nil
        shouldRemoveFrontAudio = true
        audioStatusMessage = "保存后会移除正面音频。"
    }

    private func removeBackAudio() {
        pendingAudioDownload = nil
        pendingBackAudio = nil
        shouldRemoveBackAudio = true
        audioStatusMessage = "保存后会移除背面音频。"
    }

    private func removeAllAudio() {
        pendingAudioDownload = nil
        pendingFrontAudio = nil
        pendingBackAudio = nil
        shouldRemoveFrontAudio = true
        shouldRemoveBackAudio = true
        audioStatusMessage = "保存后会移除正反两面音频。"
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

    private func storePendingManualAudioIfNeeded() throws -> (front: String?, back: String?) {
        if let pendingFrontAudio, pendingFrontAudio == pendingBackAudio {
            let storedName = try AudioFileStore.storeAudio(
                data: pendingFrontAudio.data,
                suggestedFileName: pendingFrontAudio.suggestedFileName
            )
            return (storedName, storedName)
        }

        let front = try pendingFrontAudio.map {
            try AudioFileStore.storeAudio(data: $0.data, suggestedFileName: $0.suggestedFileName)
        }
        let back = try pendingBackAudio.map {
            try AudioFileStore.storeAudio(data: $0.data, suggestedFileName: $0.suggestedFileName)
        }
        return (front, back)
    }

    private func finalFrontAudioFileName(existing: String?, shared: String?, manual: String?) -> String? {
        if shouldRemoveFrontAudio {
            return nil
        }
        return manual ?? shared ?? existing
    }

    private func finalBackAudioFileName(existing: String?, shared: String?, manual: String?) -> String? {
        if shouldRemoveBackAudio {
            return nil
        }
        return manual ?? shared ?? existing
    }

    private var hasFrontAudioCandidate: Bool {
        !shouldRemoveFrontAudio &&
            (pendingFrontAudio != nil || pendingAudioDownload != nil || editableCard?.frontAudioFileName != nil)
    }

    private var hasBackAudioCandidate: Bool {
        !shouldRemoveBackAudio &&
            (pendingBackAudio != nil || pendingAudioDownload != nil || editableCard?.backAudioFileName != nil)
    }
}

private enum AudioImportTarget {
    case front
    case back
    case both
}

private struct PendingAudioAttachment: Equatable {
    let data: Data
    let suggestedFileName: String
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
