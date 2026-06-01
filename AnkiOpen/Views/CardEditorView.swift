import SwiftUI

struct CardEditorView: View {
    enum Mode {
        case create(NotebookUnitMO)
        case createInNotebook(NotebookMO)
        case edit(FlashcardMO)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    let mode: Mode
    @State private var front: String
    @State private var back: String
    @State private var errorMessage: String?
    @State private var isShowingReport = false

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create, .createInNotebook:
            _front = State(initialValue: "")
            _back = State(initialValue: "")
        case .edit(let card):
            _front = State(initialValue: card.front)
            _back = State(initialValue: card.back)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Front") {
                    TextEditor(text: $front)
                        .flashcardCJKFont(size: 17, relativeTo: .body)
                        .frame(minHeight: 110)
                    if let warning = GlyphDiagnostics.warningSummary(for: front) {
                        Label("Rare glyphs", systemImage: "textformat.alt")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text(warning)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Back") {
                    TextEditor(text: $back)
                        .flashcardCJKFont(size: 17, relativeTo: .body)
                        .frame(minHeight: 110)
                    if let warning = GlyphDiagnostics.warningSummary(for: back) {
                        Label("Rare glyphs", systemImage: "textformat.alt")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text(warning)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if editableCard != nil {
                    Section("Report") {
                        Button {
                            isShowingReport = true
                        } label: {
                            Label("Report Card Issue", systemImage: "exclamationmark.bubble")
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(front.trimmed.isEmpty || back.trimmed.isEmpty)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
            .sheet(isPresented: $isShowingReport) {
                if let card = editableCard {
                    ReportIssueView(card: card)
                }
            }
        }
    }

    private var title: String {
        switch mode {
        case .create, .createInNotebook: return "New Card"
        case .edit: return "Edit Card"
        }
    }

    private var editableCard: FlashcardMO? {
        if case .edit(let card) = mode {
            return card
        }
        return nil
    }

    private func save() {
        let now = Date()
        switch mode {
        case .create(let unit):
            _ = FlashcardMO.insert(front: front.trimmed, back: back.trimmed, unit: unit, context: viewContext)
            unit.updatedAt = now
            unit.notebook.updatedAt = now
        case .createInNotebook(let notebook):
            _ = FlashcardMO.insert(front: front.trimmed, back: back.trimmed, notebook: notebook, context: viewContext)
            notebook.updatedAt = now
        case .edit(let card):
            card.front = front.trimmed
            card.back = back.trimmed
            card.updatedAt = now
            card.unit?.updatedAt = now
            card.notebook.updatedAt = now
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
