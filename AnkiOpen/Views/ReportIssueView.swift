import SwiftUI

struct ReportIssueView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var card: FlashcardMO
    @State private var category: ReportCategory = .audioMismatch
    @State private var note = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Card") {
                    LabeledContent("Front", value: card.front)
                    LabeledContent("Back", value: card.back)
                }

                Section("Issue") {
                    Picker("Type", selection: $category) {
                        ForEach(ReportCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }

                    TextEditor(text: $note)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Report Issue")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit", action: submit)
                }
            }
            .alert("Report Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
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
