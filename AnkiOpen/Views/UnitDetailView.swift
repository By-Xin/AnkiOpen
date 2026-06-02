import CoreData
import SwiftUI

struct UnitDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var unit: NotebookUnitMO
    @FetchRequest private var cards: FetchedResults<FlashcardMO>
    @State private var searchText = ""
    @State private var showsArchivedCards = false
    @State private var isShowingAddCard = false
    @State private var cardToEdit: FlashcardMO?
    @State private var errorMessage: String?
    @State private var isFillingAudio = false
    @State private var czyzdSummary: CZYZDAudioAttachmentSummary?
    @State private var csvExportURL: URL?

    private let czyzdAttachmentService = CZYZDAudioAttachmentService()
    private let csvExporter = CSVExporter()

    init(unit: NotebookUnitMO) {
        self.unit = unit
        let request = FlashcardMO.fetchRequest()
        request.predicate = NSPredicate(format: "unit == %@", unit)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FlashcardMO.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \FlashcardMO.createdAt, ascending: false)
        ]
        _cards = FetchRequest(fetchRequest: request, animation: .default)
    }

    var activeCards: [FlashcardMO] {
        cards.filter { !$0.isArchived }
    }

    var archivedCards: [FlashcardMO] {
        cards.filter { $0.isArchived }
    }

    var filteredActiveCards: [FlashcardMO] {
        filtered(cards: activeCards)
    }

    var filteredArchivedCards: [FlashcardMO] {
        filtered(cards: archivedCards)
    }

    private func filtered(cards: [FlashcardMO]) -> [FlashcardMO] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            return cards
        }
        return cards.filter {
            $0.front.localizedCaseInsensitiveContains(term) || $0.back.localizedCaseInsensitiveContains(term)
        }
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    StudyView(initialNotebook: unit.notebook, initialUnit: unit)
                } label: {
                    HStack {
                        LeadingSymbol(systemImage: "rectangle.stack.badge.play")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("学习这个单元")
                                .font(.headline)
                            Text("\(activeCards.count) 张可用卡片")
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
                .disabled(isFillingAudio || activeCards.isEmpty)
                .appListRow()

                Button {
                    exportCSV()
                } label: {
                    Label("生成单元 CSV", systemImage: "doc.badge.arrow.up")
                }
                .disabled(cards.isEmpty)
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

            Section("卡片") {
                if filteredActiveCards.isEmpty {
                    Text(activeCards.isEmpty ? "没有可用卡片" : "没有匹配的卡片")
                        .foregroundStyle(.secondary)
                }

                ForEach(filteredActiveCards) { card in
                    cardRow(card, isArchived: false)
                        .swipeActions {
                            Button(role: .destructive) {
                                archive(card)
                            } label: {
                                Label("归档", systemImage: "archivebox")
                            }
                        }
                }
            }

            if !archivedCards.isEmpty {
                Section("归档") {
                    Toggle("显示归档卡片", isOn: $showsArchivedCards)

                    if showsArchivedCards {
                        if filteredArchivedCards.isEmpty {
                            Text("没有匹配的归档卡片")
                                .foregroundStyle(.secondary)
                        }

                        ForEach(filteredArchivedCards) { card in
                            cardRow(card, isArchived: true)
                                .swipeActions {
                                    Button {
                                        restore(card)
                                    } label: {
                                        Label("恢复", systemImage: "arrow.uturn.backward.circle")
                                    }
                                    .tint(.green)
                                }
                        }
                    } else {
                        Text("\(archivedCards.count) 张归档卡片不会进入学习队列。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .appScreenBackground()
        .searchable(text: $searchText, prompt: "搜索卡片")
        .overlay {
            if cards.isEmpty {
                EmptyStateView(
                    title: "还没有卡片",
                    systemImage: "rectangle.stack",
                    message: "可以新建卡片，或把 CSV 导入到这个单元。"
                )
            }
        }
        .navigationTitle(unit.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddCard = true
                } label: {
                    Label("新建卡片", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingAddCard) {
            CardEditorView(mode: .create(unit))
        }
        .sheet(item: $cardToEdit) { card in
            CardEditorView(mode: .edit(card))
        }
        .alert("错误", isPresented: .constant(errorMessage != nil), actions: {
            Button("好的") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private func archive(_ card: FlashcardMO) {
        card.archive()
        do {
            try viewContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore(_ card: FlashcardMO) {
        card.restore()
        do {
            try viewContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportCSV() {
        do {
            csvExportURL = try csvExporter.writeUnitCSV(unit)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cardRow(_ card: FlashcardMO, isArchived: Bool) -> some View {
        Button {
            cardToEdit = card
        } label: {
            HStack(alignment: .top, spacing: 12) {
                LeadingSymbol(
                    systemImage: isArchived ? "archivebox" : "character.cursor.ibeam",
                    tint: isArchived ? Color.secondary : AppPalette.amber
                )
                VStack(alignment: .leading, spacing: 6) {
                    FlashcardText(
                        text: card.front,
                        size: 17,
                        relativeTo: .headline,
                        weight: .semibold,
                        lineLimit: 2
                    )
                        .foregroundStyle(isArchived ? .secondary : AppPalette.ink)
                    FlashcardText(
                        text: card.back,
                        size: 15,
                        relativeTo: .subheadline,
                        weight: .regular,
                        lineLimit: 2
                    )
                        .foregroundStyle(.secondary)
                    if GlyphDiagnostics.containsRiskyGlyphs(card.front + card.back) {
                        Label("可能含有生僻字", systemImage: "textformat.alt")
                            .font(.caption)
                            .foregroundStyle(AppPalette.cinnabar)
                    }
                    if isArchived {
                        Label("已归档", systemImage: "archivebox")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("到期 \(card.dueAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .appListRow()
    }

    @MainActor
    private func fillMissingAudio() async {
        isFillingAudio = true
        defer {
            isFillingAudio = false
        }

        czyzdSummary = await czyzdAttachmentService.attachMissingAudio(
            in: unit.notebook,
            unit: unit,
            context: viewContext
        )
    }
}
