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
