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

    func export(notebook: NotebookMO) -> String {
        export(rows: rows(for: notebook))
    }

    func export(unit: NotebookUnitMO) -> String {
        export(rows: rows(for: unit))
    }

    func writeNotebookCSV(_ notebook: NotebookMO) throws -> URL {
        try writeCSV(export(notebook: notebook), fileStem: notebook.name)
    }

    func writeUnitCSV(_ unit: NotebookUnitMO) throws -> URL {
        try writeCSV(export(unit: unit), fileStem: "\(unit.notebook.name)-\(unit.name)")
    }

    private func export(rows: [CSVExportRow]) -> String {
        let allRows = [header] + rows.map(\.columns)
        return allRows.map { row in
            row.map(Self.escape).joined(separator: ",")
        }
        .joined(separator: "\n") + "\n"
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
