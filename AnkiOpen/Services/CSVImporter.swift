import CoreData
import Foundation

struct ImportSummary: Equatable {
    let fileName: String
    let totalRows: Int
    let importedRows: Int
    let skippedRows: Int
    let audioFilesImported: Int
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
    func `import`(
        url: URL,
        into notebook: NotebookMO,
        context: NSManagedObjectContext,
        mediaURLs: [URL] = []
    ) throws -> ImportSummary {
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
        let mapping = CSVColumnMapping(rows: rows)
        let bodyRows = mapping.bodyRows
        let existingPairs = try existingCardPairs(in: notebook, context: context)
        let mediaByFileName = mediaURLs.reduce(into: [String: URL]()) { result, url in
            result[url.lastPathComponent] = url
        }

        var seenPairs = existingPairs
        var imported = 0
        var skipped = 0
        var audioImported = 0
        var errors: [String] = []

        for (index, row) in bodyRows.enumerated() {
            let sourceLine = index + 1 + (mapping.hasHeader ? 1 : 0)
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

            let audioNames = mapping.audioFileNames(from: row)
            let frontAudioFileName = copyAudioIfNeeded(
                audioNames.front,
                sourceLine: sourceLine,
                mediaByFileName: mediaByFileName,
                errors: &errors
            )
            let backAudioFileName = copyAudioIfNeeded(
                audioNames.back,
                sourceLine: sourceLine,
                mediaByFileName: mediaByFileName,
                errors: &errors
            )
            audioImported += [frontAudioFileName, backAudioFileName].compactMap { $0 }.count

            _ = FlashcardMO.insert(
                front: front,
                back: back,
                notebook: notebook,
                context: context,
                frontAudioFileName: frontAudioFileName,
                backAudioFileName: backAudioFileName
            )
            seenPairs.insert(pair)
            imported += 1
        }

        let summary = ImportSummary(
            fileName: url.lastPathComponent,
            totalRows: bodyRows.count,
            importedRows: imported,
            skippedRows: skipped,
            audioFilesImported: audioImported,
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

    private func copyAudioIfNeeded(
        _ fileName: String?,
        sourceLine: Int,
        mediaByFileName: [String: URL],
        errors: inout [String]
    ) -> String? {
        guard let fileName, !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        do {
            let copied = try AudioFileStore.copyAudio(named: fileName, from: mediaByFileName)
            return copied.isEmpty ? nil : copied
        } catch {
            errors.append("Line \(sourceLine): \(error.localizedDescription)")
            return nil
        }
    }

    private func existingCardPairs(in notebook: NotebookMO, context: NSManagedObjectContext) throws -> Set<CardPair> {
        let request = FlashcardMO.fetchRequest()
        request.predicate = NSPredicate(format: "notebook == %@", notebook)
        request.propertiesToFetch = ["front", "back"]
        return Set(try context.fetch(request).map { CardPair(front: $0.front, back: $0.back) })
    }
}

private struct CSVColumnMapping {
    let bodyRows: [[String]]
    let hasHeader: Bool
    private let frontAudioIndex: Int?
    private let backAudioIndex: Int?
    private let sharedAudioIndex: Int?

    init(rows: [[String]]) {
        guard let first = rows.first, first.count >= 2 else {
            bodyRows = rows
            hasHeader = false
            frontAudioIndex = rows.first?.indices.contains(2) == true ? 2 : nil
            backAudioIndex = rows.first?.indices.contains(3) == true ? 3 : nil
            sharedAudioIndex = nil
            return
        }

        let normalized = first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        if normalized[0] == "front", normalized[1] == "back" {
            bodyRows = Array(rows.dropFirst())
            hasHeader = true
            frontAudioIndex = normalized.firstIndex { ["frontaudio", "front_audio", "front audio"].contains($0) }
            backAudioIndex = normalized.firstIndex { ["backaudio", "back_audio", "back audio"].contains($0) }
            sharedAudioIndex = normalized.firstIndex { ["audio", "audiofilename", "audio_file", "audio file"].contains($0) }
        } else {
            bodyRows = rows
            hasHeader = false
            frontAudioIndex = first.indices.contains(2) ? 2 : nil
            backAudioIndex = first.indices.contains(3) ? 3 : nil
            sharedAudioIndex = first.indices.contains(2) && !first.indices.contains(3) ? 2 : nil
        }
    }

    func audioFileNames(from row: [String]) -> (front: String?, back: String?) {
        if let sharedAudioIndex, row.indices.contains(sharedAudioIndex) {
            let shared = row[sharedAudioIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            return (shared, shared)
        }

        let front = frontAudioIndex.flatMap { row.indices.contains($0) ? row[$0].trimmingCharacters(in: .whitespacesAndNewlines) : nil }
        let back = backAudioIndex.flatMap { row.indices.contains($0) ? row[$0].trimmingCharacters(in: .whitespacesAndNewlines) : nil }
        return (front, back)
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
