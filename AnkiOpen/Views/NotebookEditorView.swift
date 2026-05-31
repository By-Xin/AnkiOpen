import SwiftUI

struct NotebookEditorView: View {
    enum Mode {
        case create
        case edit(NotebookMO)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    let mode: Mode
    @State private var name: String
    @State private var errorMessage: String?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _name = State(initialValue: "")
        case .edit(let notebook):
            _name = State(initialValue: notebook.name)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Notebook name", text: $name)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        case .create: return "New Notebook"
        case .edit: return "Rename Notebook"
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        switch mode {
        case .create:
            let notebook = NotebookMO(context: viewContext)
            notebook.id = UUID()
            notebook.name = trimmedName
            notebook.createdAt = now
            notebook.updatedAt = now
        case .edit(let notebook):
            notebook.name = trimmedName
            notebook.updatedAt = now
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
