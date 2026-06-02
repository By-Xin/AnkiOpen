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
                TextField("笔记本名称", text: $name)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        case .create: return "新建笔记本"
        case .edit: return "重命名笔记本"
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
