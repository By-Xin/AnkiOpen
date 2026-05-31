import SwiftUI

struct UnitEditorView: View {
    enum Mode {
        case create(NotebookMO)
        case edit(NotebookUnitMO)
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
        case .edit(let unit):
            _name = State(initialValue: unit.name)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Unit") {
                    TextField("Unit name", text: $name)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmed.isEmpty)
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
        case .create: return "New Unit"
        case .edit: return "Rename Unit"
        }
    }

    private func save() {
        let now = Date()
        switch mode {
        case .create(let notebook):
            _ = NotebookUnitMO.insert(name: name.trimmed, notebook: notebook, context: viewContext)
            notebook.updatedAt = now
        case .edit(let unit):
            unit.name = name.trimmed
            unit.updatedAt = now
            unit.notebook.updatedAt = now
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
