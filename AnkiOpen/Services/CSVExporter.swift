import CoreData
import Foundation

enum CSVExporterError: LocalizedError {
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .writeFailed:
            return "CSV 文件无法写入。"
        }
    }
}

final class CSVExporter {
    private let header = ["unit", "front", "back", "frontAudio", "backAudio", "isArchived"]
    private let reportHeader = [
        "创建时间",
        "状态",
        "处理时间",
        "类型",
        "备注",
        "笔记本",
        "单元",
        "正面",
        "背面",
        "正面音频",
        "背面音频",
        "修正次数",
        "最近修正"
    ]
    private let reviewHistoryHeader = [
        "复习时间",
        "评分",
        "笔记本",
        "单元",
        "正面",
        "背面",
        "原到期",
        "新到期"
    ]

    func export(notebook: NotebookMO) -> String {
        export(rows: rows(for: notebook))
    }

    func export(unit: NotebookUnitMO) -> String {
        export(rows: rows(for: unit))
    }

    func exportReports(_ reports: [CardReportMO]) -> String {
        let allRows = [reportHeader] + reports.map(ReportCSVExportRow.init(report:)).map(\.columns)
        return rowsToCSV(allRows)
    }

    func exportReviewHistory(_ logs: [ReviewLogMO]) -> String {
        let allRows = [reviewHistoryHeader] + logs.map(ReviewHistoryCSVExportRow.init(log:)).map(\.columns)
        return rowsToCSV(allRows)
    }

    func writeNotebookCSV(_ notebook: NotebookMO) throws -> URL {
        try writeCSV(export(notebook: notebook), fileStem: notebook.name)
    }

    func writeUnitCSV(_ unit: NotebookUnitMO) throws -> URL {
        try writeCSV(export(unit: unit), fileStem: "\(unit.notebook.name)-\(unit.name)")
    }

    func writeReportsCSV(_ reports: [CardReportMO]) throws -> URL {
        try writeCSV(exportReports(reports), fileStem: "反馈记录")
    }

    func writeReviewHistoryCSV(_ logs: [ReviewLogMO]) throws -> URL {
        try writeCSV(exportReviewHistory(logs), fileStem: "复习记录")
    }

    private func export(rows: [CSVExportRow]) -> String {
        rowsToCSV([header] + rows.map(\.columns))
    }

    private func rowsToCSV(_ rows: [[String]]) -> String {
        rows.map { row in
            row.map(Self.escape).joined(separator: ",")
        }.joined(separator: "\n") + "\n"
    }

    private func rows(for notebook: NotebookMO) -> [CSVExportRow] {
        let unitRows = notebook.units
            .sorted(by: Self.sortUnits)
            .flatMap(rows)

        let orphanedRows = notebook.flashcards
            .filter { $0.unit == nil }
            .sorted(by: Self.sortCards)
            .map { CSVExportRow(unitName: NotebookUnitMO.defaultName, card: $0) }

        return unitRows + orphanedRows
    }

    private func rows(for unit: NotebookUnitMO) -> [CSVExportRow] {
        unit.flashcards
            .sorted(by: Self.sortCards)
            .map { CSVExportRow(unitName: unit.name, card: $0) }
    }

    private func writeCSV(_ csv: String, fileStem: String) throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(Self.safeFileStem(fileStem))
            .appendingPathExtension("csv")

        do {
            try Data(csv.utf8).write(to: fileURL, options: [.atomic])
            return fileURL
        } catch {
            throw CSVExporterError.writeFailed
        }
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func safeFileStem(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let scalars = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let stem = String(scalars)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
        return stem.isEmpty ? "AnkiOpen-Export" : stem
    }

    private static func sortUnits(_ lhs: NotebookUnitMO, _ rhs: NotebookUnitMO) -> Bool {
        if lhs.sortIndex == rhs.sortIndex {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.sortIndex < rhs.sortIndex
    }

    private static func sortCards(_ lhs: FlashcardMO, _ rhs: FlashcardMO) -> Bool {
        if lhs.createdAt == rhs.createdAt {
            return lhs.front < rhs.front
        }
        return lhs.createdAt < rhs.createdAt
    }
}

private struct CSVExportRow {
    let unitName: String
    let card: FlashcardMO

    var columns: [String] {
        [
            unitName,
            card.front,
            card.back,
            card.frontAudioFileName ?? "",
            card.backAudioFileName ?? "",
            card.isArchived ? "true" : "false"
        ]
    }
}

private struct ReportCSVExportRow {
    let report: CardReportMO

    var columns: [String] {
        let correctionLogs = report.correctionLogs.sorted { $0.createdAt > $1.createdAt }
        return [
            CSVDateFormatter.string(from: report.createdAt),
            report.isResolved ? "已处理" : "未处理",
            CSVDateFormatter.string(from: report.resolvedAt),
            report.categoryTitle,
            report.note,
            report.card.notebook.name,
            report.card.unit?.name ?? "",
            report.card.front,
            report.card.back,
            report.card.frontAudioFileName ?? "",
            report.card.backAudioFileName ?? "",
            "\(correctionLogs.count)",
            CSVDateFormatter.string(from: correctionLogs.first?.createdAt)
        ]
    }
}

private struct ReviewHistoryCSVExportRow {
    let log: ReviewLogMO

    var columns: [String] {
        [
            CSVDateFormatter.string(from: log.reviewedAt),
            log.ratingTitle,
            log.card.notebook.name,
            log.card.unit?.name ?? "",
            log.card.front,
            log.card.back,
            CSVDateFormatter.string(from: log.previousDueAt),
            CSVDateFormatter.string(from: log.nextDueAt)
        ]
    }
}

private enum CSVDateFormatter {
    private static let formatter = ISO8601DateFormatter()

    static func string(from date: Date?) -> String {
        guard let date else {
            return ""
        }
        return formatter.string(from: date)
    }
}
