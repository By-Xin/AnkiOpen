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
                Section("单元") {
                    TextField("单元名称", text: $name)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(name.trimmed.isEmpty)
                }
            }
            .alert("错误", isPresented: .constant(errorMessage != nil), actions: {
                Button("好的") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private var title: String {
        switch mode {
        case .create: return "新建单元"
        case .edit: return "重命名单元"
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
