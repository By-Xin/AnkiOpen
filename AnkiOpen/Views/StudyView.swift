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
            .sheet(item: $cardToReport) { card in
                ReportIssueView(card: card)
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

                        if let audioFileName = audioFileName(for: card) {
                            Button {
                                audioPlayer.play(storedFileName: audioFileName)
                            } label: {
                                Label("播放音频", systemImage: "speaker.wave.2")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.bottom, 112)
                }
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func review(_ card: FlashcardMO, rating: ReviewRating) {
        do {
            _ = try scheduler.review(card: card, rating: rating, reviewedAt: Date(), context: viewContext)
            try viewContext.save()
            dueCards.removeAll { $0.objectID == card.objectID }
            currentIndex = min(currentIndex, max(0, dueCards.count - 1))
            isShowingBack = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func audioFileName(for card: FlashcardMO) -> String? {
        isShowingBack ? card.backAudioFileName : card.frontAudioFileName
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
