import SwiftUI

struct DictionaryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \NotebookMO.updatedAt, ascending: false)],
        animation: .default
    ) private var notebooks: FetchedResults<NotebookMO>
    @StateObject private var audioPlayer = AudioPlaybackController()
    @AppStorage("czyzdDictionaryBuilderNextIndex") private var builderNextIndex = 0
    @State private var query = ""
    @State private var entries: [CZYZDDictionaryEntry] = []
    @State private var isSearching = false
    @State private var isBuildingNotebook = false
    @State private var isSavingEntry = false
    @State private var entryToSave: CZYZDDictionaryEntry?
    @State private var saveTarget: DictionarySaveTarget = .newNotebook
    @State private var saveNotebookName = CZYZDDictionaryNotebookBuilder.defaultNotebookName
    @State private var selectedExistingNotebookID: UUID?
    @State private var saveUnitName = CZYZDDictionaryNotebookBuilder.defaultUnitName
    @State private var builderNotebookName = CZYZDDictionaryNotebookBuilder.defaultNotebookName
    @State private var builderBatchSize = 10
    @State private var notebookSummary: CZYZDDictionaryNotebookImportSummary?
    @State private var errorMessage: String?

    private let lookup = CZYZDDictionaryLookup()

    var body: some View {
        NavigationStack {
            List {
                Section("查词") {
                    HStack {
                        LeadingSymbol(systemImage: "magnifyingglass")
                        TextField("输入字或词组", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit {
                                search()
                            }

                        Button {
                            search()
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .disabled(query.trimmed.isEmpty || isSearching)
                    }
                    .appListRow()
                }

                Section("词典笔记本") {
                    TextField("笔记本名称", text: $builderNotebookName)
                        .disabled(isBuildingNotebook)

                    Stepper("每批数量：\(builderBatchSize)", value: $builderBatchSize, in: 5...50, step: 5)
                        .disabled(isBuildingNotebook)

                    LabeledContent("进度", value: "\(min(builderNextIndex, CZYZDDictionaryNotebookBuilder.commonCharacterTerms.count)) / \(CZYZDDictionaryNotebookBuilder.commonCharacterTerms.count)")

                    Button {
                        Task {
                            await buildDictionaryNotebook()
                        }
                    } label: {
                        Label(isBuildingNotebook ? "下载中..." : "下载下一批", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isBuildingNotebook || builderNextIndex >= CZYZDDictionaryNotebookBuilder.commonCharacterTerms.count)

                    Button(role: .destructive) {
                        builderNextIndex = 0
                        notebookSummary = nil
                    } label: {
                        Label("重置批量进度", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(isBuildingNotebook || builderNextIndex == 0)

                    Text("这里会从内置常用字列表开始，小批量下载词典内容；中断后可以继续。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if isBuildingNotebook {
                    Section {
                        ProgressView("正在生成词典笔记本...")
                            .frame(maxWidth: .infinity)
                    }
                }

                if let notebookSummary {
                    Section("上次更新") {
                        LabeledContent("检查", value: "\(notebookSummary.checkedTerms)")
                        LabeledContent("新增", value: "\(notebookSummary.addedCards)")
                        LabeledContent("跳过", value: "\(notebookSummary.skippedCards)")
                        LabeledContent("失败", value: "\(notebookSummary.failedTerms)")
                        LabeledContent("音频", value: "\(notebookSummary.audioFilesAdded)")
                        if let messages = notebookSummary.messageSummary {
                            Text(messages)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if isSearching {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }

                if !entries.isEmpty {
                    Section("结果") {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(entry.term)
                                        .flashcardCJKFont(size: 22, relativeTo: .title3, weight: .semibold)
                                        .foregroundStyle(AppPalette.ink)

                                    Spacer()

                                    Button {
                                        saveNotebookName = "\(entry.term) 词典"
                                        saveUnitName = CZYZDDictionaryNotebookBuilder.defaultUnitName
                                        if let firstNotebook = notebooks.first {
                                            selectedExistingNotebookID = selectedExistingNotebookID ?? firstNotebook.id
                                            saveTarget = .existingNotebook
                                        } else {
                                            saveTarget = .newNotebook
                                        }
                                        entryToSave = entry
                                    } label: {
                                        Image(systemName: "plus.rectangle.on.rectangle")
                                    }
                                    .buttonStyle(.borderless)

                                    if let audioURL = entry.audioURL {
                                        Button {
                                            audioPlayer.play(remoteURL: audioURL)
                                        } label: {
                                            Image(systemName: "speaker.wave.2")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }

                                if entry.chaopinImageURL != nil || !entry.chaopin.isEmpty {
                                    LabeledContent {
                                        HStack(spacing: 8) {
                                            if let imageURL = entry.chaopinImageURL {
                                                AsyncImage(url: imageURL) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .scaledToFit()
                                                    default:
                                                        Text(entry.chaopin.isEmpty ? "潮拼图片" : entry.chaopin)
                                                            .font(.body)
                                                    }
                                                }
                                                .frame(width: 92, height: 28, alignment: .leading)
                                            }

                                            if !entry.chaopin.isEmpty {
                                                Text(entry.chaopin)
                                                    .font(.body.monospaced())
                                            }
                                        }
                                    } label: {
                                        Text("潮拼")
                                    }
                                }

                                if !entry.definition.isEmpty {
                                    LabeledContent {
                                        Text(entry.definition)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    } label: {
                                        Text("解释")
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .appListRow()
                        }
                    }
                } else if !query.trimmed.isEmpty, !isSearching {
                    Section {
                        EmptyStateView(
                            title: "没有结果",
                            systemImage: "book.closed",
                            message: "可以尝试单字，或输入精确词组。"
                        )
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
            .navigationTitle("潮语词典")
            .sheet(item: $entryToSave) { entry in
                NavigationStack {
                    Form {
                        Section("卡片") {
                            LabeledContent("正面", value: entry.term)
                            Text(CZYZDDictionaryNotebookBuilder.cardBackText(from: entry))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Section("保存位置") {
                            Picker("目标", selection: $saveTarget) {
                                ForEach(DictionarySaveTarget.available(hasExistingNotebooks: !notebooks.isEmpty)) { target in
                                    Text(target.title).tag(target)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(isSavingEntry)

                            if saveTarget == .existingNotebook, !notebooks.isEmpty {
                                Picker("笔记本", selection: $selectedExistingNotebookID) {
                                    ForEach(notebooks) { notebook in
                                        Text(notebook.name).tag(Optional(notebook.id))
                                    }
                                }
                                .disabled(isSavingEntry)

                                TextField("单元名称", text: $saveUnitName)
                                    .disabled(isSavingEntry)
                                Text("如果单元不存在，会自动创建。空白时使用默认单元。")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                TextField("笔记本名称", text: $saveNotebookName)
                                    .disabled(isSavingEntry)
                                Text("会创建一个新笔记本，并把词条保存到默认词典单元。")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if isSavingEntry {
                                ProgressView("正在保存并下载音频...")
                            }
                        }
                    }
                    .navigationTitle("保存词条")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                entryToSave = nil
                            }
                            .disabled(isSavingEntry)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                Task {
                                    await saveEntry(entry)
                                }
                            }
                            .disabled(!canSaveEntry || isSavingEntry)
                        }
                    }
                }
            }
            .alert("词典错误", isPresented: .constant(errorMessage != nil), actions: {
                Button("好的") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private var selectedExistingNotebook: NotebookMO? {
        guard let selectedExistingNotebookID else {
            return notebooks.first
        }
        return notebooks.first { $0.id == selectedExistingNotebookID } ?? notebooks.first
    }

    private var canSaveEntry: Bool {
        switch saveTarget {
        case .newNotebook:
            return !saveNotebookName.trimmed.isEmpty
        case .existingNotebook:
            return selectedExistingNotebook != nil
        }
    }

    @MainActor
    private func saveEntry(_ entry: CZYZDDictionaryEntry) async {
        isSavingEntry = true
        defer {
            isSavingEntry = false
        }

        do {
            switch saveTarget {
            case .newNotebook:
                notebookSummary = try await CZYZDDictionaryNotebookBuilder().addEntry(
                    entry,
                    toNewNotebookNamed: saveNotebookName,
                    context: viewContext
                )
                builderNotebookName = saveNotebookName
            case .existingNotebook:
                guard let notebook = selectedExistingNotebook else {
                    errorMessage = "请选择一个笔记本。"
                    return
                }
                notebookSummary = try await CZYZDDictionaryNotebookBuilder().addEntry(
                    entry,
                    toExistingNotebook: notebook,
                    unitName: saveUnitName,
                    context: viewContext
                )
                builderNotebookName = notebook.name
                selectedExistingNotebookID = notebook.id
            }
            entryToSave = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func buildDictionaryNotebook() async {
        isBuildingNotebook = true
        defer {
            isBuildingNotebook = false
        }

        let summary = await CZYZDDictionaryNotebookBuilder().importCommonTerms(
            intoNotebookNamed: builderNotebookName,
            startingAt: builderNextIndex,
            limit: builderBatchSize,
            context: viewContext
        )
        notebookSummary = summary
        builderNextIndex = summary.nextIndex
    }

    private func search() {
        let cleanQuery = query.trimmed
        guard !cleanQuery.isEmpty else {
            return
        }

        isSearching = true
        errorMessage = nil
        entries = []

        Task {
            do {
                let results = try await lookup.lookup(term: cleanQuery)
                await MainActor.run {
                    entries = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSearching = false
                }
            }
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum DictionarySaveTarget: String, CaseIterable, Identifiable {
    case existingNotebook
    case newNotebook

    var id: String { rawValue }

    var title: String {
        switch self {
        case .existingNotebook:
            return "已有笔记本"
        case .newNotebook:
            return "新建笔记本"
        }
    }

    static func available(hasExistingNotebooks: Bool) -> [DictionarySaveTarget] {
        hasExistingNotebooks ? [.existingNotebook, .newNotebook] : [.newNotebook]
    }
}
