import CoreData
import SwiftUI

struct UnitDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var unit: NotebookUnitMO
    @FetchRequest private var cards: FetchedResults<FlashcardMO>
    @State private var searchText = ""
    @State private var isShowingAddCard = false
    @State private var cardToEdit: FlashcardMO?
    @State private var errorMessage: String?
    @State private var isFillingAudio = false
    @State private var czyzdSummary: CZYZDAudioAttachmentSummary?

    private let czyzdAttachmentService = CZYZDAudioAttachmentService()

    init(unit: NotebookUnitMO) {
        self.unit = unit
        let request = FlashcardMO.fetchRequest()
        request.predicate = NSPredicate(format: "unit == %@ AND isArchived == NO", unit)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FlashcardMO.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \FlashcardMO.createdAt, ascending: false)
        ]
        _cards = FetchRequest(fetchRequest: request, animation: .default)
    }

    var filteredCards: [FlashcardMO] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            return Array(cards)
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
                            Text("\(cards.count) 张可用卡片")
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
                .disabled(isFillingAudio || cards.isEmpty)
                .appListRow()
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
                ForEach(filteredCards) { card in
                    Button {
                        cardToEdit = card
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            LeadingSymbol(systemImage: "character.cursor.ibeam", tint: AppPalette.amber)
                            VStack(alignment: .leading, spacing: 6) {
                                FlashcardText(
                                    text: card.front,
                                    size: 17,
                                    relativeTo: .headline,
                                    weight: .semibold,
                                    lineLimit: 2
                                )
                                    .foregroundStyle(AppPalette.ink)
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
                                Text("到期 \(card.dueAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .appListRow()
                    .swipeActions {
                        Button(role: .destructive) {
                            archive(card)
                        } label: {
                            Label("归档", systemImage: "archivebox")
                        }
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
        card.isArchived = true
        card.updatedAt = Date()
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
            in: unit.notebook,
            unit: unit,
            context: viewContext
        )
    }
}
