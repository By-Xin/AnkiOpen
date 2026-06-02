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
