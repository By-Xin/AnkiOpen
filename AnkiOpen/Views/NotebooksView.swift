import CoreData
import SwiftUI

struct NotebooksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var notebooks: FetchedResults<NotebookMO>
    @State private var isShowingAddNotebook = false
    @State private var notebookToEdit: NotebookMO?
    @State private var errorMessage: String?

    init() {
        let request = NotebookMO.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NotebookMO.updatedAt, ascending: false)]
        _notebooks = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("开始") {
                    NavigationLink {
                        StudyView()
                    } label: {
                        HStack(spacing: 12) {
                            LeadingSymbol(systemImage: "rectangle.stack.badge.play")
                            VStack(alignment: .leading, spacing: 6) {
                                Text("开始学习")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppPalette.ink)
                                Text("复习所有已到期的卡片，也可以开启随机学习")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .appListRow()
                }

                Section("工具") {
                    NavigationLink {
                        ImportView()
                    } label: {
                        Label("导入 CSV", systemImage: "square.and.arrow.down")
                    }
                    .appListRow()

                    NavigationLink {
                        DictionaryView()
                    } label: {
                        Label("潮语词典", systemImage: "character.book.closed")
                    }
                    .appListRow()

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("设置与备份", systemImage: "gearshape")
                    }
                    .appListRow()
                }

                Section("笔记本") {
                    if notebooks.isEmpty {
                        EmptyStateView(
                            title: "还没有笔记本",
                            systemImage: "books.vertical",
                            message: "新建笔记本，或从 CSV 导入一批卡片。"
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(notebooks) { notebook in
                            NavigationLink {
                                NotebookDetailView(notebook: notebook)
                            } label: {
                                HStack(spacing: 12) {
                                    LeadingSymbol(systemImage: "books.vertical")
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(notebook.name)
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppPalette.ink)
                                        Text("更新于 \(notebook.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 12)
                                    MetricPill(value: "\(notebook.unitsCount)", label: "单元")
                                    MetricPill(value: "\(notebook.activeCardsCount)", label: "卡片", tint: AppPalette.amber)
                                }
                            }
                            .appListRow()
                            .swipeActions(edge: .leading) {
                                Button {
                                    notebookToEdit = notebook
                                } label: {
                                    Label("重命名", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
            .navigationTitle("潮语闪卡")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddNotebook = true
                    } label: {
                        Label("新建笔记本", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddNotebook) {
                NotebookEditorView(mode: .create)
            }
            .sheet(item: $notebookToEdit) { notebook in
                NotebookEditorView(mode: .edit(notebook))
            }
            .alert("错误", isPresented: .constant(errorMessage != nil), actions: {
                Button("好的") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private func delete(offsets: IndexSet) {
        offsets.map { notebooks[$0] }.forEach(viewContext.delete)
        do {
            try viewContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
