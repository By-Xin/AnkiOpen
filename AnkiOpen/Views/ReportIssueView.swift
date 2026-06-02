import SwiftUI

struct ReportIssueView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var card: FlashcardMO
    @State private var category: ReportCategory = .audioMismatch
    @State private var note = ""
    @State private var errorMessage: String?

    init(card: FlashcardMO, initialCategory: ReportCategory = .audioMismatch, initialNote: String = "") {
        self.card = card
        _category = State(initialValue: initialCategory)
        _note = State(initialValue: initialNote)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("卡片") {
                    LabeledContent("正面", value: card.front)
                    LabeledContent("背面", value: card.back)
                }

                Section("问题") {
                    Picker("类型", selection: $category) {
                        ForEach(ReportCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }

                    TextEditor(text: $note)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("反馈问题")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("提交", action: submit)
                }
            }
            .alert("反馈错误", isPresented: .constant(errorMessage != nil), actions: {
                Button("好的") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private func submit() {
        _ = CardReportMO.insert(
            card: card,
            category: category,
            note: note,
            context: viewContext
        )

        do {
            try viewContext.save()
            dismiss()
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
