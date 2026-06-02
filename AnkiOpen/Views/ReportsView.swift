import SwiftUI

struct ReportsView: View {
    @FetchRequest private var reports: FetchedResults<CardReportMO>
    @State private var filter: ReportStatusFilter = .open

    init() {
        let request = CardReportMO.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CardReportMO.createdAt, ascending: false)
        ]
        _reports = FetchRequest(fetchRequest: request, animation: .default)
    }

    private var filteredReports: [CardReportMO] {
        reports.filter { report in
            switch filter {
            case .open:
                return !report.isResolved
            case .resolved:
                return report.isResolved
            }
        }
    }

    var body: some View {
        List {
            Section {
                Picker("状态", selection: $filter) {
                    ForEach(ReportStatusFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            if filteredReports.isEmpty {
                Section {
                    EmptyStateView(
                        title: filter.emptyTitle,
                        systemImage: filter.emptySystemImage,
                        message: filter.emptyMessage
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section(filter.title) {
                    ForEach(filteredReports) { report in
                        NavigationLink {
                            ReportDetailView(report: report)
                        } label: {
                            ReportRow(report: report)
                        }
                    }
                }
            }
        }
        .navigationTitle("反馈")
    }
}

private struct ReportRow: View {
    @ObservedObject var report: CardReportMO

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(report.categoryTitle, systemImage: report.isResolved ? "checkmark.circle" : "exclamationmark.bubble")
                    .font(.headline)
                Spacer()
                Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            FlashcardText(
                text: report.card.front,
                size: 15,
                relativeTo: .subheadline,
                weight: .regular,
                lineLimit: 1
            )
            .foregroundStyle(.primary)

            if !report.note.isEmpty {
                Text(report.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ReportDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var report: CardReportMO
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isShowingCardEditor = false
    @State private var pendingCorrectionSnapshot: CardCorrectionSnapshot?

    private var correctionLogs: [CardCorrectionLogMO] {
        report.correctionLogs.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Form {
            Section("状态") {
                LabeledContent("类型", value: report.categoryTitle)
                LabeledContent("创建时间", value: report.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let resolvedAt = report.resolvedAt {
                    LabeledContent("已处理", value: resolvedAt.formatted(date: .abbreviated, time: .shortened))
                } else {
                    LabeledContent("已处理", value: "否")
                }
            }

            Section("卡片") {
                LabeledContent("笔记本", value: report.card.notebook.name)
                if let unit = report.card.unit {
                    LabeledContent("单元", value: unit.name)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("正面")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlashcardText(text: report.card.front, size: 17, relativeTo: .body, weight: .regular)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("背面")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlashcardText(text: report.card.back, size: 17, relativeTo: .body, weight: .regular)
                }

                Button {
                    pendingCorrectionSnapshot = CardCorrectionSnapshot(card: report.card)
                    isShowingCardEditor = true
                } label: {
                    Label("编辑卡片", systemImage: "pencil")
                }

                Text("从这里编辑并保存卡片后，会自动记录修正前后内容；如果内容或音频有变化，该反馈会自动标记为已处理。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !report.note.isEmpty {
                Section("备注") {
                    Text(report.note)
                }
            }

            if !correctionLogs.isEmpty {
                Section("修正记录") {
                    ForEach(correctionLogs) { log in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(log.changedFieldTitles.joined(separator: "、"), systemImage: "wrench.adjustable")
                                    .font(.subheadline)
                                Spacer()
                                Text(log.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(log.changedFieldTitles, id: \.self) { title in
                                correctionSummaryRow(title: title, log: log)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    toggleResolved()
                } label: {
                    Label(report.isResolved ? "重新打开反馈" : "标记为已处理", systemImage: report.isResolved ? "arrow.uturn.backward" : "checkmark.circle")
                }
            }
        }
        .navigationTitle("反馈详情")
        .sheet(isPresented: $isShowingCardEditor) {
            CardEditorView(mode: .edit(report.card)) { card in
                recordCorrectionIfNeeded(after: card)
            }
        }
        .alert("反馈错误", isPresented: .constant(errorMessage != nil), actions: {
            Button("好的") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    @ViewBuilder
    private func correctionSummaryRow(title: String, log: CardCorrectionLogMO) -> some View {
        switch title {
        case "正面":
            Text("正面: \(log.previousFront) -> \(log.nextFront)")
                .font(.caption)
                .foregroundStyle(.secondary)
        case "背面":
            Text("背面已更新")
                .font(.caption)
                .foregroundStyle(.secondary)
        case "正面音频":
            Text("正面音频: \(audioDisplayName(log.previousFrontAudioFileName)) -> \(audioDisplayName(log.nextFrontAudioFileName))")
                .font(.caption)
                .foregroundStyle(.secondary)
        case "背面音频":
            Text("背面音频: \(audioDisplayName(log.previousBackAudioFileName)) -> \(audioDisplayName(log.nextBackAudioFileName))")
                .font(.caption)
                .foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    private func audioDisplayName(_ fileName: String?) -> String {
        fileName ?? "无"
    }

    private func recordCorrectionIfNeeded(after card: FlashcardMO) {
        guard let before = pendingCorrectionSnapshot else {
            return
        }
        pendingCorrectionSnapshot = nil

        let after = CardCorrectionSnapshot(card: card)
        guard before != after else {
            statusMessage = "没有检测到卡片内容或音频变化，反馈保持当前状态。"
            return
        }

        _ = CardCorrectionLogMO.insert(
            report: report,
            card: card,
            before: before,
            after: after,
            context: viewContext
        )
        report.markResolved()

        do {
            try viewContext.save()
            statusMessage = "已记录修正并标记为已处理。"
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func toggleResolved() {
        if report.isResolved {
            report.reopen()
            statusMessage = "反馈已重新打开。"
        } else {
            report.markResolved()
            statusMessage = "反馈已标记为已处理。"
        }

        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private enum ReportStatusFilter: String, CaseIterable, Identifiable {
    case open
    case resolved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open:
            return "未处理"
        case .resolved:
            return "已处理"
        }
    }

    var emptyTitle: String {
        switch self {
        case .open:
            return "没有未处理反馈"
        case .resolved:
            return "没有已处理反馈"
        }
    }

    var emptySystemImage: String {
        switch self {
        case .open:
            return "checkmark.circle"
        case .resolved:
            return "tray"
        }
    }

    var emptyMessage: String {
        switch self {
        case .open:
            return "新的卡片问题会显示在这里，直到标记为已处理。"
        case .resolved:
            return "已处理的问题会保留在这里，方便后续复查。"
        }
    }
}
