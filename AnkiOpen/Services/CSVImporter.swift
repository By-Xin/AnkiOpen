import CoreData
import Foundation

struct ImportSummary: Equatable {
    let fileName: String
    let totalRows: Int
    let importedRows: Int
    let skippedRows: Int
    let errors: [String]

    var errorsSummary: String? {
        errors.isEmpty ? nil : errors.joined(separator: "\n")
    }
}

enum CSVImporterError: LocalizedError {
    case unreadableFile
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "The selected CSV file could not be read."
        case .invalidEncoding:
            return "The CSV file must be UTF-8 encoded."
        }
    }
}

final class CSVImporter {
    func `import`(url: URL, into notebook: NotebookMO, context: NSManagedObjectContext) throws -> ImportSummary {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else {
            throw CSVImporterError.unreadableFile
        }
        guard let contents = String(data: data, encoding: .utf8) else {
            throw CSVImporterError.invalidEncoding
        }

        let rows = CSVParser.parse(contents)
        let bodyRows = dropHeaderIfPresent(rows)
        let existingPairs = try existingCardPairs(in: notebook, context: context)

        var seenPairs = existingPairs
        var imported = 0
        var skipped = 0
        var errors: [String] = []

        for (index, row) in bodyRows.enumerated() {
            let sourceLine = index + 1 + (bodyRows.count == rows.count ? 0 : 1)
            guard row.count >= 2 else {
                errors.append("Line \(sourceLine): expected at least two columns.")
                skipped += 1
                continue
            }

            let front = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let back = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !front.isEmpty, !back.isEmpty else {
                errors.append("Line \(sourceLine): front and back must both be non-empty.")
                skipped += 1
                continue
            }

            let pair = CardPair(front: front, back: back)
            guard !seenPairs.contains(pair) else {
                skipped += 1
                continue
            }

            _ = FlashcardMO.insert(front: front, back: back, notebook: notebook, context: context)
            seenPairs.insert(pair)
            imported += 1
        }

        let summary = ImportSummary(
            fileName: url.lastPathComponent,
            totalRows: bodyRows.count,
            importedRows: imported,
            skippedRows: skipped,
            errors: errors
        )

        let batch = ImportBatchMO(context: context)
        batch.id = UUID()
        batch.fileName = summary.fileName
        batch.importedAt = Date()
        batch.totalRows = Int32(summary.totalRows)
        batch.importedRows = Int32(summary.importedRows)
        batch.skippedRows = Int32(summary.skippedRows)
        batch.errorsSummary = summary.errorsSummary
        batch.notebook = notebook

        notebook.updatedAt = Date()
        return summary
    }

    private func dropHeaderIfPresent(_ rows: [[String]]) -> [[String]] {
        guard let first = rows.first, first.count >= 2 else {
            return rows
        }

        let front = first[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let back = first[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if front == "front", back == "back" {
            return Array(rows.dropFirst())
        }
        return rows
    }

    private func existingCardPairs(in notebook: NotebookMO, context: NSManagedObjectContext) throws -> Set<CardPair> {
        let request = FlashcardMO.fetchRequest()
        request.predicate = NSPredicate(format: "notebook == %@", notebook)
        request.propertiesToFetch = ["front", "back"]
        return Set(try context.fetch(request).map { CardPair(front: $0.front, back: $0.back) })
    }
}

private struct CardPair: Hashable {
    let front: String
    let back: String
}

enum CSVParser {
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if isInQuotes {
                if character == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        isInQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    isInQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field)
                    append(row: row, to: &rows)
                    row = []
                    field = ""
                case "\r":
                    break
                default:
                    field.append(character)
                }
            }

            index = text.index(after: index)
        }

        row.append(field)
        append(row: row, to: &rows)
        return rows
    }

    private static func append(row: [String], to rows: inout [[String]]) {
        let isBlank = row.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !isBlank {
            rows.append(row)
        }
    }
}
