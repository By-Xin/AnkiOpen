import CoreData
import SwiftUI

struct NotebooksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var notebooks: FetchedResults<NotebookMO>
    @FetchRequest private var cards: FetchedResults<FlashcardMO>
    @FetchRequest private var reports: FetchedResults<CardReportMO>
    @FetchRequest private var reviewLogs: FetchedResults<ReviewLogMO>
    @State private var isShowingAddNotebook = false
    @State private var notebookToEdit: NotebookMO?
    @State private var errorMessage: String?
    @State private var now = Date()

    init() {
        let request = NotebookMO.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NotebookMO.updatedAt, ascending: false)]
        _notebooks = FetchRequest(fetchRequest: request, animation: .default)

        let cardRequest = FlashcardMO.fetchRequest()
        cardRequest.sortDescriptors = [NSSortDescriptor(keyPath: \FlashcardMO.dueAt, ascending: true)]
        _cards = FetchRequest(fetchRequest: cardRequest, animation: .default)

        let reportRequest = CardReportMO.fetchRequest()
        reportRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CardReportMO.createdAt, ascending: false)]
        _reports = FetchRequest(fetchRequest: reportRequest, animation: .default)

        let reviewLogRequest = ReviewLogMO.fetchRequest()
        reviewLogRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ReviewLogMO.reviewedAt, ascending: false)]
        _reviewLogs = FetchRequest(fetchRequest: reviewLogRequest, animation: .default)
    }

    private var metrics: HomeDashboardMetrics {
        HomeDashboardMetrics(cards: Array(cards), reports: Array(reports), reviewLogs: Array(reviewLogs), at: now)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("今日") {
                    NavigationLink {
                        StudyView()
                    } label: {
                        HStack(spacing: 12) {
                            LeadingSymbol(systemImage: "rectangle.stack.badge.play")
                            VStack(alignment: .leading, spacing: 6) {
                                Text("开始学习")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppPalette.ink)
                                Text(metrics.dueCards == 0 ? "今天没有到期卡片，也可以强制学习或随机复习" : "\(metrics.dueCards) 张到期，按 FSRS 顺序复习")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 12)
                            MetricPill(value: "\(metrics.dueCards)", label: "到期", tint: AppPalette.cinnabar)
                        }
                    }
                    .appListRow()

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                        MetricPill(value: "\(metrics.reviewedToday)", label: "今日复习", tint: AppPalette.tea)
                        MetricPill(value: "\(metrics.reviewedLast7Days)", label: "近7日", tint: AppPalette.tea)
                        MetricPill(value: "\(metrics.activeCards)", label: "可用")
                        MetricPill(value: "\(metrics.archivedCards)", label: "归档", tint: .secondary)
                        MetricPill(value: "\(metrics.missingAudioCards)", label: "缺音频", tint: AppPalette.amber)
                        MetricPill(value: "\(metrics.openReports)", label: "反馈", tint: AppPalette.cinnabar)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appListRow()
                }

                Section("工具") {
                    NavigationLink {
                        ImportView()
                    } label: {
                        Label("导入 CSV", systemImage: "square.and.arrow.down")
                    }
                    .appListRow()

                    NavigationLink {
                        DictionaryView()
                    } label: {
                        Label("潮语词典", systemImage: "character.book.closed")
                    }
                    .appListRow()

                    NavigationLink {
                        MissingAudioCardsView()
                    } label: {
                        Label("缺音频卡片", systemImage: "speaker.slash")
                    }
                    .appListRow()

                    NavigationLink {
                        ReviewHistoryView()
                    } label: {
                        Label("复习记录", systemImage: "clock.arrow.circlepath")
                    }
                    .appListRow()

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("设置与备份", systemImage: "gearshape")
                    }
                    .appListRow()
                }

                Section("笔记本") {
                    if notebooks.isEmpty {
                        EmptyStateView(
                            title: "还没有笔记本",
                            systemImage: "books.vertical",
                            message: "新建笔记本，或从 CSV 导入一批卡片。"
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
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
                                        Text(notebookSubtitle(for: notebook))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 12)
                                    MetricPill(value: "\(notebook.unitsCount)", label: "单元")
                                    MetricPill(value: "\(notebook.activeCardsCount)", label: "卡片", tint: AppPalette.amber)
                                }
                            }
                            .appListRow()
                            .swipeActions(edge: .leading) {
                                Button {
                                    notebookToEdit = notebook
                                } label: {
                                    Label("重命名", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
            .navigationTitle("潮语闪卡")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                now = Date()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddNotebook = true
                    } label: {
                        Label("新建笔记本", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddNotebook) {
                NotebookEditorView(mode: .create)
            }
            .sheet(item: $notebookToEdit) { notebook in
                NotebookEditorView(mode: .edit(notebook))
            }
            .alert("错误", isPresented: .constant(errorMessage != nil), actions: {
                Button("好的") { errorMessage = nil }
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

    private func notebookSubtitle(for notebook: NotebookMO) -> String {
        let updated = notebook.updatedAt.formatted(date: .abbreviated, time: .omitted)
        let dueCount = notebook.dueCardsCount(at: now)
        guard dueCount > 0 else {
            return "更新于 \(updated)"
        }
        return "更新于 \(updated) · \(dueCount) 张到期"
    }
}

private struct ReviewHistoryView: View {
    @FetchRequest private var reviewLogs: FetchedResults<ReviewLogMO>
    @State private var searchText = ""
    @State private var csvExportURL: URL?
    @State private var errorMessage: String?

    private let csvExporter = CSVExporter()

    init() {
        let request = ReviewLogMO.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReviewLogMO.reviewedAt, ascending: false)
        ]
        request.fetchLimit = 300
        _reviewLogs = FetchRequest(fetchRequest: request, animation: .default)
    }

    private var filteredLogs: [ReviewLogMO] {
        let filter = ReviewHistoryFilter(searchText: searchText)
        return reviewLogs.filter(filter.matches)
    }

    private var isSearchEmpty: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        List {
            if filteredLogs.isEmpty {
                Section {
                    EmptyStateView(
                        title: isSearchEmpty ? "还没有复习记录" : "没有匹配记录",
                        systemImage: "clock.arrow.circlepath",
                        message: isSearchEmpty ? "完成一次学习后，这里会显示最近复习过的卡片。" : "换一个卡片、笔记本、单元或评分关键词再试。"
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            } else {
                if let csvExportURL {
                    Section("导出") {
                        ShareLink(item: csvExportURL) {
                            Label("分享复习记录 CSV", systemImage: "square.and.arrow.up")
                        }
                        Text(csvExportURL.lastPathComponent)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("最近复习") {
                    ForEach(filteredLogs) { log in
                        NavigationLink {
                            ReviewHistoryDetailView(log: log)
                        } label: {
                            ReviewHistoryRow(log: log)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .appScreenBackground()
        .navigationTitle("复习记录")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索卡片、笔记本或评分")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exportCSV()
                } label: {
                    Label("导出 CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(filteredLogs.isEmpty)
            }
        }
        .alert("导出错误", isPresented: .constant(errorMessage != nil), actions: {
            Button("好的") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private func exportCSV() {
        do {
            csvExportURL = try csvExporter.writeReviewHistoryCSV(filteredLogs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ReviewHistoryRow: View {
    @ObservedObject var log: ReviewLogMO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(log.ratingTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint(for: log.ratingValue))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(tint(for: log.ratingValue).opacity(0.12), in: Capsule())

                Spacer()

                Text(log.reviewedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            FlashcardText(
                text: log.card.front,
                size: 16,
                relativeTo: .subheadline,
                weight: .regular,
                lineLimit: 2
            )
            .foregroundStyle(AppPalette.ink)

            Text(cardLocation(for: log.card))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func cardLocation(for card: FlashcardMO) -> String {
        if let unit = card.unit {
            return "\(card.notebook.name) / \(unit.name)"
        }
        return card.notebook.name
    }

    private func tint(for rating: ReviewRating?) -> Color {
        switch rating {
        case .again:
            return AppPalette.cinnabar
        case .hard:
            return AppPalette.amber
        case .good:
            return AppPalette.tea
        case .easy:
            return .indigo
        case nil:
            return .secondary
        }
    }
}

private struct ReviewHistoryDetailView: View {
    @ObservedObject var log: ReviewLogMO
    @State private var isShowingCardEditor = false

    var body: some View {
        Form {
            Section("复习") {
                LabeledContent("评分", value: log.ratingTitle)
                LabeledContent("复习时间", value: log.reviewedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("原到期", value: log.previousDueAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("新到期", value: log.nextDueAt.formatted(date: .abbreviated, time: .shortened))
            }

            Section("卡片") {
                LabeledContent("笔记本", value: log.card.notebook.name)
                if let unit = log.card.unit {
                    LabeledContent("单元", value: unit.name)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("正面")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlashcardText(text: log.card.front, size: 17, relativeTo: .body, weight: .regular)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("背面")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlashcardText(text: log.card.back, size: 17, relativeTo: .body, weight: .regular)
                }

                Button {
                    isShowingCardEditor = true
                } label: {
                    Label("编辑卡片", systemImage: "pencil")
                }
            }
        }
        .navigationTitle("记录详情")
        .sheet(isPresented: $isShowingCardEditor) {
            CardEditorView(mode: .edit(log.card))
        }
    }
}

private struct MissingAudioCardsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var cards: FetchedResults<FlashcardMO>
    @State private var searchText = ""
    @State private var scope: MissingAudioScope = .all
    @State private var cardToEdit: FlashcardMO?
    @State private var isFillingAudio = false
    @State private var czyzdSummary: CZYZDAudioAttachmentSummary?
    @State private var errorMessage: String?

    private let czyzdAttachmentService = CZYZDAudioAttachmentService()

    init() {
        let request = FlashcardMO.fetchRequest()
        request.predicate = NSPredicate(
            format: "isArchived == NO AND (frontAudioFileName == nil OR backAudioFileName == nil)"
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FlashcardMO.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \FlashcardMO.createdAt, ascending: false)
        ]
        _cards = FetchRequest(fetchRequest: request, animation: .default)
    }

    private var allMissingCards: [FlashcardMO] {
        cards.filter(\.isMissingAudio)
    }

    private var filteredCards: [FlashcardMO] {
        let filter = MissingAudioCardFilter(scope: scope, searchText: searchText)
        return allMissingCards.filter(filter.matches)
    }

    private var summary: MissingAudioSummary {
        MissingAudioSummary(cards: allMissingCards)
    }

    var body: some View {
        List {
            Section("概览") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    MetricPill(value: "\(summary.total)", label: "总数", tint: AppPalette.amber)
                    MetricPill(value: "\(summary.missingFront)", label: "缺正面", tint: AppPalette.cinnabar)
                    MetricPill(value: "\(summary.missingBack)", label: "缺背面", tint: AppPalette.tea)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task {
                        await fillAllMissingAudio()
                    }
                } label: {
                    Label(
                        isFillingAudio ? "正在批量补全..." : "批量补全潮语音频",
                        systemImage: "speaker.wave.2.badge.plus"
                    )
                }
                .disabled(isFillingAudio || allMissingCards.isEmpty)

                Text("会优先复用卡片另一面已有的本地音频；两面都缺时，再按正面文字从 CZYZD 匹配音频。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let czyzdSummary {
                Section("本次处理") {
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

            Section("筛选") {
                Picker("范围", selection: $scope) {
                    ForEach(MissingAudioScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("卡片") {
                if filteredCards.isEmpty {
                    EmptyStateView(
                        title: allMissingCards.isEmpty ? "音频都已补齐" : "没有匹配的卡片",
                        systemImage: "speaker.wave.2",
                        message: allMissingCards.isEmpty ? "当前没有未归档的缺音频卡片。" : "换一个关键词或筛选范围再试。"
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredCards) { card in
                        Button {
                            cardToEdit = card
                        } label: {
                            MissingAudioCardRow(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .appScreenBackground()
        .navigationTitle("缺音频卡片")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索卡片、笔记本或单元")
        .sheet(item: $cardToEdit) { card in
            CardEditorView(mode: .edit(card))
        }
        .alert("错误", isPresented: .constant(errorMessage != nil), actions: {
            Button("好的") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    @MainActor
    private func fillAllMissingAudio() async {
        isFillingAudio = true
        defer {
            isFillingAudio = false
        }

        var summaries: [CZYZDAudioAttachmentSummary] = []
        let notebooks = uniqueNotebooks(from: allMissingCards)
        for notebook in notebooks {
            summaries.append(
                await czyzdAttachmentService.attachMissingAudio(
                    in: notebook,
                    context: viewContext
                )
            )
        }
        czyzdSummary = CZYZDAudioAttachmentSummary.combined(summaries)
    }

    private func uniqueNotebooks(from cards: [FlashcardMO]) -> [NotebookMO] {
        var seen = Set<UUID>()
        var notebooks: [NotebookMO] = []
        for card in cards {
            guard !seen.contains(card.notebook.id) else {
                continue
            }
            seen.insert(card.notebook.id)
            notebooks.append(card.notebook)
        }
        return notebooks
    }
}

private struct MissingAudioSummary: Equatable {
    let total: Int
    let missingFront: Int
    let missingBack: Int

    init(cards: [FlashcardMO]) {
        total = cards.filter(\.isMissingAudio).count
        missingFront = cards.filter { $0.isMissingAudio && $0.frontAudioFileName == nil }.count
        missingBack = cards.filter { $0.isMissingAudio && $0.backAudioFileName == nil }.count
    }
}

private struct MissingAudioCardRow: View {
    @ObservedObject var card: FlashcardMO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LeadingSymbol(systemImage: "speaker.slash", tint: AppPalette.amber)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(card.missingAudioTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.cinnabar)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(AppPalette.cinnabar.opacity(0.12), in: Capsule())
                    Spacer(minLength: 8)
                }

                FlashcardText(
                    text: card.front,
                    size: 16,
                    relativeTo: .headline,
                    weight: .semibold,
                    lineLimit: 2
                )
                .foregroundStyle(AppPalette.ink)

                FlashcardText(
                    text: card.back,
                    size: 14,
                    relativeTo: .subheadline,
                    weight: .regular,
                    lineLimit: 2
                )
                .foregroundStyle(.secondary)

                Text(card.locationTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private extension CZYZDAudioAttachmentSummary {
    static func combined(_ summaries: [CZYZDAudioAttachmentSummary]) -> CZYZDAudioAttachmentSummary {
        CZYZDAudioAttachmentSummary(
            checkedCards: summaries.reduce(0) { $0 + $1.checkedCards },
            matchedCards: summaries.reduce(0) { $0 + $1.matchedCards },
            failedCards: summaries.reduce(0) { $0 + $1.failedCards },
            messages: summaries.flatMap(\.messages)
        )
    }
}
