import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var reports: FetchedResults<CardReportMO>
    @State private var backupURL: URL?
    @State private var importSummary: BackupImportSummary?
    @State private var isShowingBackupImporter = false
    @State private var errorMessage: String?
    @State private var deepSeekAPIKey = ""
    @State private var deepSeekModel = DeepSeekSettingsStore.selectedModel
    @State private var isDeepSeekDictionaryParsingEnabled = DeepSeekSettingsStore.isDictionaryParsingEnabled
    @State private var deepSeekStatusMessage: String?

    private let backupExporter = BackupExporter()
    private let backupImporter = BackupImporter()

    init() {
        let request = CardReportMO.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CardReportMO.createdAt, ascending: false)]
        _reports = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("复习算法") {
                    HStack(spacing: 12) {
                        LeadingSymbol(systemImage: "calendar.badge.clock")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FSRS")
                                .font(.headline)
                            Text("目标记忆率 0.90 · FSRS-6 默认参数")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("DeepSeek") {
                    SecureField("API Key", text: $deepSeekAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("模型", selection: $deepSeekModel) {
                        ForEach(DeepSeekModel.allCases) { model in
                            Text(model.title).tag(model)
                        }
                    }

                    Toggle("清洗潮语词典结果", isOn: $isDeepSeekDictionaryParsingEnabled)
                        .onChange(of: isDeepSeekDictionaryParsingEnabled) { value in
                            DeepSeekSettingsStore.isDictionaryParsingEnabled = value
                        }

                    LabeledContent("接口", value: "api.deepseek.com")

                    Button {
                        saveDeepSeekSettings()
                    } label: {
                        Label("保存 DeepSeek 设置", systemImage: "key")
                    }

                    if let deepSeekStatusMessage {
                        Text(deepSeekStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("用于生僻字和词典清洗：生僻字会询问替代字；词典会把网页结果整理成潮拼和解释。默认使用 V4 Flash，优先保证速度。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("数据") {
                    LabeledContent("存储", value: "本机 Core Data")
                    LabeledContent("同步", value: "关闭")

                    Button {
                        createBackup()
                    } label: {
                        Label("创建 JSON 备份", systemImage: "externaldrive.badge.timemachine")
                    }

                    Button {
                        isShowingBackupImporter = true
                    } label: {
                        Label("导入 JSON 备份", systemImage: "tray.and.arrow.down")
                    }

                    if let backupURL {
                        ShareLink(item: backupURL) {
                            Label("分享备份", systemImage: "square.and.arrow.up")
                        }
                        Text(backupURL.lastPathComponent)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let importSummary {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("上次恢复")
                                .font(.headline)
                            Text(importSummary.fileName)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text("\(importSummary.importedNotebooks) 个笔记本，\(importSummary.importedUnits) 个单元，\(importSummary.importedCards) 张卡片，\(importSummary.importedReviewLogs) 条复习记录")
                                .font(.footnote)
                            Text("已恢复 \(importSummary.importedMediaFiles) 个媒体文件")
                                .font(.footnote)
                            Text("已跳过 \(importSummary.skippedDuplicates) 个重复项")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("反馈") {
                    NavigationLink {
                        ReportsView()
                    } label: {
                        HStack {
                            Label("反馈", systemImage: "exclamationmark.bubble")
                            Spacer()
                            Text("\(openReportsCount) 个未处理")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("本机反馈", value: "\(reports.count)")
                    Text("反馈目前只保存在本机。等校对流程稳定后，再加入云端提交或导出。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("文字") {
                    NavigationLink {
                        RareGlyphsView()
                    } label: {
                        Label("生僻字", systemImage: "textformat.alt")
                    }
                }

                Section("开源") {
                    LabeledContent("许可证", value: "MIT")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppPalette.paper.ignoresSafeArea())
            .navigationTitle("设置")
            .fileImporter(
                isPresented: $isShowingBackupImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                importBackup(result)
            }
            .alert("备份错误", isPresented: .constant(errorMessage != nil), actions: {
                Button("好的") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
            .onAppear {
                deepSeekAPIKey = DeepSeekSettingsStore.loadAPIKey()
                deepSeekModel = DeepSeekSettingsStore.selectedModel
                isDeepSeekDictionaryParsingEnabled = DeepSeekSettingsStore.isDictionaryParsingEnabled
            }
            .onChange(of: deepSeekModel) { model in
                DeepSeekSettingsStore.selectedModel = model
            }
        }
    }

    private var openReportsCount: Int {
        reports.filter { !$0.isResolved }.count
    }

    private func createBackup() {
        do {
            backupURL = try backupExporter.writeBackup(context: viewContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importBackup(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }
            importSummary = try backupImporter.import(url: url, context: viewContext)
            try viewContext.save()
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func saveDeepSeekSettings() {
        do {
            try DeepSeekSettingsStore.saveAPIKey(deepSeekAPIKey)
            DeepSeekSettingsStore.selectedModel = deepSeekModel
            DeepSeekSettingsStore.isDictionaryParsingEnabled = isDeepSeekDictionaryParsingEnabled
            deepSeekStatusMessage = deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "API Key 已清空。"
                : "DeepSeek 设置已保存。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
