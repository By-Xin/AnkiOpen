import CoreData
import SwiftUI

struct RareGlyphsView: View {
    @FetchRequest private var cards: FetchedResults<FlashcardMO>

    init() {
        let request = FlashcardMO.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FlashcardMO.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \FlashcardMO.createdAt, ascending: false)
        ]
        _cards = FetchRequest(fetchRequest: request, animation: .default)
    }

    private var items: [GlyphInventoryItem] {
        GlyphInventory.items(for: Array(cards))
    }

    var body: some View {
        List {
            if items.isEmpty {
                EmptyStateView(
                    title: "没有发现生僻字",
                    systemImage: "textformat.alt",
                    message: "当前导入的卡片里没有高风险字形。"
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                Section("生僻字") {
                    ForEach(items) { item in
                        NavigationLink {
                            RareGlyphDetailView(item: item)
                        } label: {
                            HStack(spacing: 14) {
                                GlyphPreview(scalar: item.finding.scalar, size: 44)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.finding.codePoint)
                                        .font(.headline)
                                    Text(item.finding.category.rawValue)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("\(item.occurrences) 次，分布在 \(item.cards.count) 张卡片")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    GlyphSuggestionStatusLabel(finding: item.finding)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("生僻字")
    }
}

private struct RareGlyphDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let item: GlyphInventoryItem
    @State private var suggestion: GlyphReplacementSuggestion?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("字形") {
                HStack(spacing: 16) {
                    GlyphPreview(scalar: item.finding.scalar, size: 76)

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("码位", value: item.finding.codePoint)
                        LabeledContent("范围", value: item.finding.category.rawValue)
                        LabeledContent("出现次数", value: "\(item.occurrences)")
                        LabeledContent("DeepSeek", value: suggestion?.replacement ?? "暂无建议")
                    }
                }
            }

            Section("DeepSeek 替代字") {
                if let suggestion {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("替换为", value: suggestion.replacement)
                        Text(suggestion.explanation)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        applySuggestion(suggestion)
                    } label: {
                        Label("应用到 \(item.cards.count) 张卡片", systemImage: "wand.and.stars")
                    }
                }

                Button {
                    requestSuggestion()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Label("询问 DeepSeek", systemImage: "sparkles")
                    }
                }
                .disabled(isLoading)

                Text("DeepSeek 会给出更适合显示和学习的替代字。应用前请先检查建议是否符合语义。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("相关卡片") {
                ForEach(item.cards) { card in
                    VStack(alignment: .leading, spacing: 6) {
                        FlashcardText(
                            text: card.front,
                            size: 17,
                            relativeTo: .headline,
                            weight: .semibold,
                            lineLimit: 2
                        )
                        .foregroundStyle(.primary)

                        FlashcardText(
                            text: card.back,
                            size: 15,
                            relativeTo: .subheadline,
                            weight: .regular,
                            lineLimit: 2
                        )
                        .foregroundStyle(.secondary)

                        Text("\(card.notebook.name) / \(card.unit?.name ?? "默认单元")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .navigationTitle(item.finding.codePoint)
        .onAppear {
            suggestion = GlyphReplacementSuggestionStore.suggestion(for: item.finding.scalar)
        }
        .alert("DeepSeek 错误", isPresented: .constant(errorMessage != nil), actions: {
            Button("好的") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private func requestSuggestion() {
        isLoading = true
        errorMessage = nil
        let scalar = item.finding.scalar
        let examples = item.cards.map { "\($0.front) / \($0.back)" }

        Task {
            do {
                let value = try await DeepSeekGlyphSuggestionClient().suggestReplacement(for: scalar, examples: examples)
                await MainActor.run {
                    GlyphReplacementSuggestionStore.save(value)
                    suggestion = value
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func applySuggestion(_ suggestion: GlyphReplacementSuggestion) {
        for card in item.cards {
            card.front = replacing(item.finding.scalar, in: card.front, with: suggestion.replacement)
            card.back = replacing(item.finding.scalar, in: card.back, with: suggestion.replacement)
            card.updatedAt = Date()
        }

        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func replacing(_ target: UnicodeScalar, in text: String, with replacement: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            if scalar.value == target.value {
                result.append(replacement)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}

private struct GlyphSuggestionStatusLabel: View {
    let finding: GlyphDiagnostics.Finding

    var body: some View {
        Label(finding.suggestionStatusTitle, systemImage: finding.hasSuggestion ? "checkmark.circle" : "sparkles")
            .font(.caption)
            .foregroundStyle(finding.hasSuggestion ? .green : .orange)
    }
}

private struct GlyphPreview: View {
    let scalar: UnicodeScalar
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.thinMaterial)
            Text(String(scalar))
                .flashcardCJKFont(size: size * 0.7, relativeTo: .title2)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(String(scalar)))
    }
}
