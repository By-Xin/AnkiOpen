import SwiftUI

struct CardEditorView: View {
    enum Mode {
        case create(NotebookMO)
        case edit(FlashcardMO)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    let mode: Mode
    @State private var front: String
    @State private var back: String
    @State private var errorMessage: String?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
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
                        .frame(minHeight: 110)
                }
                Section("Back") {
                    TextEditor(text: $back)
                        .frame(minHeight: 110)
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
        }
    }

    private var title: String {
        switch mode {
        case .create: return "New Card"
        case .edit: return "Edit Card"
        }
    }

    private func save() {
        let now = Date()
        switch mode {
        case .create(let notebook):
            _ = FlashcardMO.insert(front: front.trimmed, back: back.trimmed, notebook: notebook, context: viewContext)
            notebook.updatedAt = now
        case .edit(let card):
            card.front = front.trimmed
            card.back = back.trimmed
            card.updatedAt = now
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
