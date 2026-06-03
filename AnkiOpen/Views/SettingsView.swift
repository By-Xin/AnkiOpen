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

                    NavigationLink {
                        PrivacyDisclosureView()
                    } label: {
                        Label("隐私与数据说明", systemImage: "lock.shield")
                    }

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
                            Text("\(importSummary.importedReports) 条反馈，\(importSummary.importedCorrectionLogs) 条修正记录")
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
                    Text("反馈和修正记录会随 JSON 备份一起导出；后续再加入云端提交。")
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

                Section("发布") {
                    NavigationLink {
                        ReleaseChecklistView()
                    } label: {
                        Label("发布与验收清单", systemImage: "checklist")
                    }

                    Text("用于每次真机安装、日常学习前检查，以及后续 TestFlight/App Store 发布准备。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

struct PrivacyDisclosureItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
}

enum PrivacyDisclosureLibrary {
    static let items: [PrivacyDisclosureItem] = [
        PrivacyDisclosureItem(
            id: "local-storage",
            title: "本机离线存储",
            detail: "笔记本、单元、卡片、复习记录、反馈、修正历史和音频文件默认只保存在本机。App 第一版不使用账号系统，也不自动同步到云端。"
        ),
        PrivacyDisclosureItem(
            id: "csv-backup",
            title: "导入和备份由你控制",
            detail: "CSV、音频文件和 JSON 备份只在你主动选择文件、创建备份或分享备份时处理。备份文件可能包含卡片内容、反馈记录和本地音频。"
        ),
        PrivacyDisclosureItem(
            id: "czyzd-network",
            title: "潮语词典和音频请求",
            detail: "使用潮语词典查询、导入后自动查词、批量构建词典笔记本或自动补全潮语音频时，App 会向 CZYZD 查询对应词条和音频。"
        ),
        PrivacyDisclosureItem(
            id: "deepseek-network",
            title: "DeepSeek 只在配置后使用",
            detail: "只有当你在设置中填写 API Key，并主动使用生僻字建议或开启词典清洗时，App 才会向 DeepSeek 发送需要处理的字词或词典文本。API Key 保存在本机 Keychain。"
        ),
        PrivacyDisclosureItem(
            id: "no-tracking",
            title: "第一版不做行为追踪",
            detail: "App 不包含广告、第三方分析 SDK、账号画像或远程学习统计。发布前仍需要在 App Store Connect 中按实际功能填写隐私问卷。"
        )
    ]
}

private struct PrivacyDisclosureView: View {
    var body: some View {
        List {
            Section("概览") {
                Text("AnkiOpen 第一版以本机离线学习为主。外部网络请求只在你使用潮语词典、潮语音频匹配，或配置 DeepSeek 后触发。")
                    .font(.body)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("数据流向") {
                ForEach(PrivacyDisclosureLibrary.items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(AppPalette.ink)
                        Text(item.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .appScreenBackground()
        .navigationTitle("隐私与数据")
    }
}

struct ReleaseChecklistSection: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [ReleaseChecklistItem]
}

struct ReleaseChecklistItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
}

enum ReleaseChecklistLibrary {
    static let sections: [ReleaseChecklistSection] = [
        ReleaseChecklistSection(
            id: "daily",
            title: "日常使用",
            items: [
                ReleaseChecklistItem(
                    id: "daily-import",
                    title: "导入一个真实 CSV",
                    detail: "确认笔记本、单元、卡片数量正确，中文和生僻字能显示。"
                ),
                ReleaseChecklistItem(
                    id: "daily-study",
                    title: "完成一轮学习",
                    detail: "检查翻面、四档评分、shuffle、强制学习和完成摘要。"
                ),
                ReleaseChecklistItem(
                    id: "daily-audio",
                    title: "检查音频播放",
                    detail: "至少试听正面、背面、词典匹配和手动导入的音频。"
                ),
                ReleaseChecklistItem(
                    id: "daily-backup",
                    title: "创建 JSON 备份",
                    detail: "确认备份文件能分享出去，必要时在模拟器或空库恢复一次。"
                )
            ]
        ),
        ReleaseChecklistSection(
            id: "dictionary",
            title: "潮语词典",
            items: [
                ReleaseChecklistItem(
                    id: "dictionary-lookup",
                    title: "查一个单字和一个词组",
                    detail: "确认词组不会错误退回第一个字，结果有潮拼和解释。"
                ),
                ReleaseChecklistItem(
                    id: "dictionary-deepseek",
                    title: "检查 DeepSeek 清洗",
                    detail: "如果配置了 API Key，确认词典结果能整理为潮拼和解释。"
                ),
                ReleaseChecklistItem(
                    id: "dictionary-save",
                    title: "保存词典结果为笔记本",
                    detail: "确认生成卡片、音频和单元结构都正确。"
                )
            ]
        ),
        ReleaseChecklistSection(
            id: "reports",
            title: "反馈修正",
            items: [
                ReleaseChecklistItem(
                    id: "reports-create",
                    title: "提交一个卡片反馈",
                    detail: "覆盖音频不匹配、读音/拼音错误、释义错误或其他类型。"
                ),
                ReleaseChecklistItem(
                    id: "reports-resolve",
                    title: "从反馈进入修正",
                    detail: "保存修改后确认反馈自动处理，并生成修正记录。"
                ),
                ReleaseChecklistItem(
                    id: "reports-export",
                    title: "导出反馈 CSV",
                    detail: "确认当前筛选结果能分享为表格，用于后续批量整理。"
                )
            ]
        ),
        ReleaseChecklistSection(
            id: "release",
            title: "TestFlight / App Store",
            items: [
                ReleaseChecklistItem(
                    id: "release-tests",
                    title: "本地测试和 GitHub CI 通过",
                    detail: "确认 Xcode 测试、UI smoke test、远端 Actions 都是绿色。"
                ),
                ReleaseChecklistItem(
                    id: "release-device",
                    title: "真机安装和启动",
                    detail: "确认手机已解锁、Developer Mode 可用，并能打开最新版 App。"
                ),
                ReleaseChecklistItem(
                    id: "release-signing",
                    title: "确认签名和 Bundle ID",
                    detail: "使用 com.xinby.AnkiOpen，自动签名账号和 Team 正确。"
                ),
                ReleaseChecklistItem(
                    id: "release-privacy",
                    title: "检查隐私说明",
                    detail: "说明本机离线存储、DeepSeek 仅在配置 API Key 后请求外部接口。"
                )
            ]
        )
    ]

    static var allItems: [ReleaseChecklistItem] {
        sections.flatMap(\.items)
    }

    static func completedCount(in completedIDs: Set<String>) -> Int {
        allItems.filter { completedIDs.contains($0.id) }.count
    }
}

private struct ReleaseChecklistView: View {
    @AppStorage("releaseChecklistCompletedIDs") private var completedIDsStorage = ""

    private var completedIDs: Set<String> {
        get {
            Set(completedIDsStorage.split(separator: ",").map(String.init))
        }
        nonmutating set {
            completedIDsStorage = newValue.sorted().joined(separator: ",")
        }
    }

    private var completedCount: Int {
        ReleaseChecklistLibrary.completedCount(in: completedIDs)
    }

    private var totalCount: Int {
        ReleaseChecklistLibrary.allItems.count
    }

    var body: some View {
        List {
            Section("进度") {
                HStack(spacing: 10) {
                    ReportChecklistMetric(value: "\(completedCount)", label: "已完成", tint: AppPalette.tea)
                    ReportChecklistMetric(value: "\(totalCount - completedCount)", label: "剩余", tint: AppPalette.amber)
                    ReportChecklistMetric(value: "\(totalCount)", label: "总项", tint: .secondary)
                }
                .padding(.vertical, 4)

                ProgressView(value: Double(completedCount), total: Double(max(totalCount, 1)))
                    .tint(AppPalette.tea)

                Button {
                    completedIDs = []
                } label: {
                    Label("重置清单", systemImage: "arrow.counterclockwise")
                }
                .disabled(completedCount == 0)
            }

            ForEach(ReleaseChecklistLibrary.sections) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        ReleaseChecklistRow(
                            item: item,
                            isCompleted: completedIDs.contains(item.id),
                            toggle: {
                                toggle(item)
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .appScreenBackground()
        .navigationTitle("发布与验收")
    }

    private func toggle(_ item: ReleaseChecklistItem) {
        var ids = completedIDs
        if ids.contains(item.id) {
            ids.remove(item.id)
        } else {
            ids.insert(item.id)
        }
        completedIDs = ids
    }
}

private struct ReleaseChecklistRow: View {
    let item: ReleaseChecklistItem
    let isCompleted: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? AppPalette.tea : .secondary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

private struct ReportChecklistMetric: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
