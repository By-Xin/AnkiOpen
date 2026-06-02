import CoreData
import SwiftUI

struct StudyView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var notebooks: FetchedResults<NotebookMO>
    @State private var selectedNotebook: NotebookMO?
    @State private var selectedUnit: NotebookUnitMO?
    @State private var studyMode: StudyMode = .due
    @State private var isShuffleEnabled = false
    @State private var dueCards: [FlashcardMO] = []
    @State private var currentIndex = 0
    @State private var isShowingBack = false
    @State private var errorMessage: String?
    @State private var cardToReport: FlashcardMO?
    @State private var cardToEdit: FlashcardMO?
    @State private var reportContext: StudyReportContext?
    @State private var sessionSummary = StudySessionSummary()
    @StateObject private var audioPlayer = AudioPlaybackController()

    private let scheduler = ReviewScheduler()

    init(initialNotebook: NotebookMO? = nil, initialUnit: NotebookUnitMO? = nil) {
        _selectedNotebook = State(initialValue: initialUnit?.notebook ?? initialNotebook)
        _selectedUnit = State(initialValue: initialUnit)
        let request = NotebookMO.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NotebookMO.name, ascending: true)]
        _notebooks = FetchRequest(fetchRequest: request, animation: .default)
    }

    private var currentCard: FlashcardMO? {
        guard dueCards.indices.contains(currentIndex) else {
            return nil
        }
        return dueCards[currentIndex]
    }

    var body: some View {
        NavigationStack {
            studyContent
            .padding(.top, 8)
            .background(AppPalette.paper.ignoresSafeArea())
            .navigationTitle("学习")
            .safeAreaInset(edge: .bottom) {
                if let card = currentCard {
                    studyActionBar(for: card)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        reportContext = nil
                        cardToReport = currentCard
                    } label: {
                        Label("反馈", systemImage: "exclamationmark.bubble")
                    }
                    .disabled(currentCard == nil)

                    Button {
                        reloadDueCards()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
            }
            .onAppear(perform: reloadDueCards)
            .onChange(of: selectedNotebook?.id) { _ in
                reloadDueCards()
            }
            .onChange(of: studyMode) { _ in
                reloadDueCards()
            }
            .onChange(of: isShuffleEnabled) { _ in
                reloadDueCards()
            }
            .alert("错误", isPresented: .constant(errorMessage != nil), actions: {
                Button("好的") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
            .sheet(item: $cardToReport, onDismiss: {
                reportContext = nil
            }) { card in
                ReportIssueView(
                    card: card,
                    initialCategory: reportContext?.category ?? .audioMismatch,
                    initialNote: reportContext?.note ?? ""
                )
            }
            .sheet(item: $cardToEdit, onDismiss: reloadDueCards) { card in
                CardEditorView(mode: .edit(card))
            }
        }
    }

    private var studyContent: some View {
        VStack(spacing: 16) {
            if let selectedUnit {
                LabeledContent("单元", value: "\(selectedUnit.notebook.name) / \(selectedUnit.name)")
                    .padding(.horizontal)
                    .foregroundStyle(.secondary)
            } else {
                Picker("笔记本", selection: notebookSelection) {
                    Text("全部笔记本").tag(UUID?.none)
                    ForEach(notebooks) { notebook in
                        Text(notebook.name).tag(Optional(notebook.id))
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
            }

            Picker("学习模式", selection: $studyMode) {
                ForEach(StudyMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Toggle(isOn: $isShuffleEnabled) {
                Label("随机顺序", systemImage: "shuffle")
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .padding(.horizontal)

            if let card = currentCard {
                ScrollView {
                    VStack(spacing: 18) {
                        HStack {
                            MetricPill(value: "\(currentIndex + 1)", label: "当前")
                            ProgressView(value: Double(currentIndex + 1), total: Double(max(dueCards.count, 1)))
                                .tint(AppPalette.tea)
                            MetricPill(value: "\(dueCards.count)", label: "待学", tint: AppPalette.amber)
                        }
                        .padding(.horizontal)

                        cardFaceButton(for: card)

                        studyCardTools(for: card)
                    }
                    .padding(.bottom, 112)
                }
            } else if sessionSummary.hasReviewed {
                completionSummary
            } else {
                EmptyStateView(
                    title: studyMode.emptyTitle,
                    systemImage: "checkmark.circle",
                    message: studyMode.emptyMessage
                )
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var completionSummary: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(AppPalette.tea)
                    .frame(width: 76, height: 76)
                    .background(AppPalette.teaSoft, in: RoundedRectangle(cornerRadius: 8))

                VStack(spacing: 6) {
                    Text("本轮学习完成")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                    Text("已复习 \(sessionSummary.reviewedCount) 张卡片")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    ForEach(ReviewRating.allCases) { rating in
                        MetricPill(
                            value: "\(sessionSummary.count(for: rating))",
                            label: rating.title,
                            tint: tint(for: rating)
                        )
                    }
                }

                VStack(spacing: 10) {
                    Button {
                        reloadDueCards()
                    } label: {
                        Label("重新检查到期卡片", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if studyMode != .notDue {
                        Button {
                            studyMode = .notDue
                            isShuffleEnabled = true
                        } label: {
                            Label("强制学习未到期卡片", systemImage: "forward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    if studyMode != .all || !isShuffleEnabled {
                        Button {
                            studyMode = .all
                            isShuffleEnabled = true
                        } label: {
                            Label("随机学习全部卡片", systemImage: "shuffle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    private func cardFaceButton(for card: FlashcardMO) -> some View {
        Button {
            withAnimation(.easeInOut) {
                isShowingBack.toggle()
            }
        } label: {
            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    Text(isShowingBack ? "背面" : "正面")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isShowingBack ? AppPalette.amber : AppPalette.tea)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            (isShowingBack ? AppPalette.amber : AppPalette.tea).opacity(0.12),
                            in: Capsule()
                        )
                    if audioFileName(for: card) != nil {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundStyle(AppPalette.tea)
                    }
                }
                let displayText = isShowingBack ? card.back : card.front
                FlashcardText(
                    text: displayText,
                    size: 26,
                    relativeTo: .title2,
                    weight: .regular,
                    alignment: .center
                )
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 260)

                if GlyphDiagnostics.containsRiskyGlyphs(displayText) {
                    Label("可能含有生僻字", systemImage: "textformat.alt")
                        .font(.caption)
                        .foregroundStyle(AppPalette.cinnabar)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.tea.opacity(0.16), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private func studyActionBar(for card: FlashcardMO) -> some View {
        VStack(spacing: 10) {
            if isShowingBack {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    ForEach(ReviewRating.allCases) { rating in
                        Button(rating.title) {
                            review(card, rating: rating)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .tint(tint(for: rating))
                    }
                }
            } else {
                Button {
                    withAnimation(.easeInOut) {
                        isShowingBack = true
                    }
                } label: {
                    Label("显示答案", systemImage: "eye")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }

    private func studyCardTools(for card: FlashcardMO) -> some View {
        let currentSideMissingAudio = audioFileName(for: card) == nil

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(
                    audioStatusTitle(for: card),
                    systemImage: currentSideMissingAudio ? "speaker.slash" : "speaker.wave.2.fill"
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(currentSideMissingAudio ? AppPalette.cinnabar : AppPalette.tea)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        (currentSideMissingAudio ? AppPalette.cinnabar : AppPalette.tea).opacity(0.12),
                        in: Capsule()
                    )

                Spacer(minLength: 10)

                Text(card.locationTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                if let audioFileName = audioFileName(for: card) {
                    Button {
                        audioPlayer.play(storedFileName: audioFileName)
                    } label: {
                        Label(isShowingBack ? "播放背面" : "播放正面", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.tea)
                } else {
                    Button {
                        report(card, category: .audioMismatch, note: "\(isShowingBack ? "背面" : "正面")缺少音频。")
                    } label: {
                        Label("反馈缺音频", systemImage: "exclamationmark.bubble")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.cinnabar)
                }

                Button {
                    cardToEdit = card
                } label: {
                    Label("编辑卡片", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
            }

            if card.needsAudioAttention {
                Text("这张卡片\(card.missingAudioTitle)，可以先反馈问题，也可以编辑卡片并用潮语词典匹配或手动选择音频。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke((currentSideMissingAudio ? AppPalette.cinnabar : AppPalette.tea).opacity(0.14), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var notebookSelection: Binding<UUID?> {
        Binding {
            selectedNotebook?.id
        } set: { id in
            selectedNotebook = notebooks.first { $0.id == id }
            selectedUnit = nil
        }
    }

    private func reloadDueCards() {
        do {
            let cards = try DueCardQuery.forNotebook(selectedNotebook, unit: selectedUnit, mode: studyMode, at: Date(), context: viewContext)
            dueCards = StudyQueueOrder.apply(to: cards, shuffle: isShuffleEnabled)
            currentIndex = 0
            isShowingBack = false
            sessionSummary.reset()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func review(_ card: FlashcardMO, rating: ReviewRating) {
        do {
            _ = try scheduler.review(card: card, rating: rating, reviewedAt: Date(), context: viewContext)
            try viewContext.save()
            sessionSummary.record(rating)
            dueCards.removeAll { $0.objectID == card.objectID }
            currentIndex = min(currentIndex, max(0, dueCards.count - 1))
            isShowingBack = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func report(_ card: FlashcardMO, category: ReportCategory, note: String = "") {
        reportContext = StudyReportContext(category: category, note: note)
        cardToReport = card
    }

    private func audioFileName(for card: FlashcardMO) -> String? {
        let storedFileName = isShowingBack ? card.backAudioFileName : card.frontAudioFileName
        guard AudioFileStore.storedAudioExists(storedFileName) else {
            return nil
        }
        return AudioFileStore.cleanedStoredFileName(storedFileName)
    }

    private func audioStatusTitle(for card: FlashcardMO) -> String {
        if audioFileName(for: card) == nil {
            return isShowingBack ? "当前背面缺音频" : "当前正面缺音频"
        }
        return isShowingBack ? "背面有音频" : "正面有音频"
    }

    private func tint(for rating: ReviewRating) -> Color {
        switch rating {
        case .again:
            return AppPalette.cinnabar
        case .hard:
            return AppPalette.amber
        case .good:
            return AppPalette.tea
        case .easy:
            return .indigo
        }
    }
}

private struct StudyReportContext {
    let category: ReportCategory
    let note: String
}
