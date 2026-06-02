import CoreData
import SwiftUI

struct NotebookDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var notebook: NotebookMO
    @FetchRequest private var units: FetchedResults<NotebookUnitMO>
    @State private var isShowingAddUnit = false
    @State private var unitToEdit: NotebookUnitMO?
    @State private var errorMessage: String?
    @State private var isFillingAudio = false
    @State private var czyzdSummary: CZYZDAudioAttachmentSummary?
    @State private var csvExportURL: URL?

    private let czyzdAttachmentService = CZYZDAudioAttachmentService()
    private let csvExporter = CSVExporter()

    init(notebook: NotebookMO) {
        self.notebook = notebook
        let request = NotebookUnitMO.fetchRequest()
        request.predicate = NSPredicate(format: "notebook == %@", notebook)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \NotebookUnitMO.sortIndex, ascending: true),
            NSSortDescriptor(keyPath: \NotebookUnitMO.createdAt, ascending: true)
        ]
        _units = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    StudyView(initialNotebook: notebook)
                } label: {
                    HStack {
                        LeadingSymbol(systemImage: "rectangle.stack.badge.play")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("复习到期卡片")
                                .font(.headline)
                            Text("\(notebook.activeCardsCount) 张可用卡片")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .appListRow()

                Button {
                    Task {
                        await fillMissingAudio()
                    }
                } label: {
                    Label(
                        isFillingAudio ? "正在补全潮语音频..." : "补全缺失的潮语音频",
                        systemImage: "speaker.wave.2.badge.plus"
                    )
                }
                .disabled(isFillingAudio || notebook.activeCardsCount == 0)
                .appListRow()

                Button {
                    exportCSV()
                } label: {
                    Label("生成笔记本 CSV", systemImage: "doc.badge.arrow.up")
                }
                .disabled(notebook.flashcards.isEmpty)
                .appListRow()

                if let csvExportURL {
                    ShareLink(item: csvExportURL) {
                        Label("分享 CSV", systemImage: "square.and.arrow.up")
                    }
                    .appListRow()
                    Text(csvExportURL.lastPathComponent)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

            Section("单元") {
                ForEach(units) { unit in
                    NavigationLink {
                        UnitDetailView(unit: unit)
                    } label: {
                        HStack(spacing: 12) {
                            LeadingSymbol(systemImage: "folder")
                            VStack(alignment: .leading, spacing: 6) {
                                Text(unit.name)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppPalette.ink)
                                Text("第 \(unit.sortIndex + 1) 单元")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            MetricPill(value: "\(unit.activeCardsCount)", label: "卡片", tint: AppPalette.amber)
                        }
                    }
                    .appListRow()
                    .swipeActions(edge: .leading) {
                        Button {
                            unitToEdit = unit
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(unit)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .appScreenBackground()
        .overlay {
            if units.isEmpty {
                EmptyStateView(
                    title: "还没有单元",
                    systemImage: "folder",
                    message: "可以新建单元，或把 CSV 导入到这个笔记本。"
                )
            }
        }
        .navigationTitle(notebook.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddUnit = true
                } label: {
                    Label("新建单元", systemImage: "plus")
                }
            }
        }
        .onAppear(perform: ensureDefaultUnitsForLegacyCards)
        .sheet(isPresented: $isShowingAddUnit) {
            UnitEditorView(mode: .create(notebook))
        }
        .sheet(item: $unitToEdit) { unit in
            UnitEditorView(mode: .edit(unit))
        }
        .alert("错误", isPresented: .constant(errorMessage != nil), actions: {
            Button("好的") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private func delete(_ unit: NotebookUnitMO) {
        viewContext.delete(unit)
        do {
            try viewContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportCSV() {
        do {
            csvExportURL = try csvExporter.writeNotebookCSV(notebook)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ensureDefaultUnitsForLegacyCards() {
        let orphanedCards = notebook.flashcards.filter { $0.unit == nil }
        guard !orphanedCards.isEmpty else {
            return
        }

        let defaultUnit = NotebookUnitMO.findOrCreateDefault(in: notebook, context: viewContext)
        orphanedCards.forEach { $0.unit = defaultUnit }
        do {
            try viewContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func fillMissingAudio() async {
        isFillingAudio = true
        defer {
            isFillingAudio = false
        }

        czyzdSummary = await czyzdAttachmentService.attachMissingAudio(
            in: notebook,
            context: viewContext
        )
    }
}
