import CoreData
import Foundation

struct ImportUnitSummary: Equatable, Identifiable {
    let name: String
    let importedCards: Int

    var id: String {
        name
    }
}

struct ImportSummary: Equatable {
    let fileName: String
    let totalRows: Int
    let importedRows: Int
    let skippedRows: Int
    let audioFilesImported: Int
    let unitNames: [String]
    let unitSummaries: [ImportUnitSummary]
    let skippedRowDetails: [String]
    let errors: [String]
    let glyphWarnings: [String]
    let importedCardIDs: [UUID]
    let dictionaryLookupRows: Int
    let dictionaryLookupTermsByCardID: [UUID: String]

    init(
        fileName: String,
        totalRows: Int,
        importedRows: Int,
        skippedRows: Int,
        audioFilesImported: Int,
        unitNames: [String] = [],
        unitSummaries: [ImportUnitSummary] = [],
        skippedRowDetails: [String] = [],
        errors: [String],
        glyphWarnings: [String] = [],
        importedCardIDs: [UUID] = [],
        dictionaryLookupRows: Int = 0,
        dictionaryLookupTermsByCardID: [UUID: String] = [:]
    ) {
        self.fileName = fileName
        self.totalRows = totalRows
        self.importedRows = importedRows
        self.skippedRows = skippedRows
        self.audioFilesImported = audioFilesImported
        self.unitNames = unitNames
        self.unitSummaries = unitSummaries
        self.skippedRowDetails = skippedRowDetails
        self.errors = errors
        self.glyphWarnings = glyphWarnings
        self.importedCardIDs = importedCardIDs
        self.dictionaryLookupRows = dictionaryLookupRows
        self.dictionaryLookupTermsByCardID = dictionaryLookupTermsByCardID
    }

    var errorsSummary: String? {
        errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    var glyphWarningsSummary: String? {
        glyphWarnings.isEmpty ? nil : glyphWarnings.joined(separator: "\n")
    }

    var issueCount: Int {
        skippedRowDetails.count + errors.count + glyphWarnings.count
    }
}

struct ImportPreview: Equatable {
    let fileName: String
    let totalRows: Int
    let importableRows: Int
    let skippedRows: Int
    let duplicateRows: Int
    let units: [String]
    let missingAudioFiles: [String]
    let unsupportedAudioFiles: [String]
    let skippedRowDetails: [String]
    let errors: [String]
    let audioWarnings: [String]
    let glyphWarnings: [String]
    let dictionaryLookupRows: Int

    var canImport: Bool {
        importableRows > 0
    }

    var errorsSummary: String? {
        errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    var audioWarningsSummary: String? {
        audioWarnings.isEmpty ? nil : audioWarnings.joined(separator: "\n")
    }

    var glyphWarningsSummary: String? {
        glyphWarnings.isEmpty ? nil : glyphWarnings.joined(separator: "\n")
    }

    var issueCount: Int {
        skippedRowDetails.count + errors.count + audioWarnings.count + glyphWarnings.count
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
    func preview(
        url: URL,
        into notebook: NotebookMO?,
        context: NSManagedObjectContext,
        mediaURLs: [URL] = []
    ) throws -> ImportPreview {
        let scopedMediaURLs = startAccessing(urls: mediaURLs)
        defer { stopAccessing(scopedMediaURLs) }

        let existingPairs = try notebook.map { try existingCardPairs(in: $0, context: context) } ?? []
        let plan = try analyze(url: url, existingPairs: existingPairs, mediaURLs: mediaURLs)
        return plan.preview
    }

    func `import`(
        url: URL,
        into notebook: NotebookMO,
        context: NSManagedObjectContext,
        mediaURLs: [URL] = []
    ) throws -> ImportSummary {
        let scopedMediaURLs = startAccessing(urls: mediaURLs)
        defer { stopAccessing(scopedMediaURLs) }

        let existingPairs = try existingCardPairs(in: notebook, context: context)
        let plan = try analyze(url: url, existingPairs: existingPairs, mediaURLs: mediaURLs)
        let mediaByFileName = mediaFilesByFileName(from: mediaURLs)

        var imported = 0
        var audioImported = 0
        var errors = plan.errors + plan.audioWarnings
        var importedCardIDs: [UUID] = []
        var dictionaryLookupTermsByCardID: [UUID: String] = [:]
        var importedCardsByUnitName: [String: Int] = [:]

        for row in plan.rows {
            let unit = NotebookUnitMO.findOrCreate(
                named: row.unitName,
                in: notebook,
                context: context
            )
            let frontAudioFileName = copyAudioIfNeeded(
                row.frontAudioFileName,
                sourceLine: row.sourceLine,
                mediaByFileName: mediaByFileName,
                errors: &errors
            )
            let backAudioFileName = copyAudioIfNeeded(
                row.backAudioFileName,
                sourceLine: row.sourceLine,
                mediaByFileName: mediaByFileName,
                errors: &errors
            )
            audioImported += [frontAudioFileName, backAudioFileName].compactMap { $0 }.count

            let card = FlashcardMO.insert(
                front: row.front,
                back: row.back,
                unit: unit,
                context: context,
                frontAudioFileName: frontAudioFileName,
                backAudioFileName: backAudioFileName
            )
            importedCardIDs.append(card.id)
            if let dictionaryLookupTerm = row.dictionaryLookupTerm {
                dictionaryLookupTermsByCardID[card.id] = dictionaryLookupTerm
            }
            importedCardsByUnitName[unit.name, default: 0] += 1
            imported += 1
        }

        let unitSummaries = plan.unitNames.map { unitName in
            ImportUnitSummary(
                name: unitName,
                importedCards: importedCardsByUnitName[unitName, default: 0]
            )
        }

        let summary = ImportSummary(
            fileName: plan.fileName,
            totalRows: plan.totalRows,
            importedRows: imported,
            skippedRows: plan.skippedRows,
            audioFilesImported: audioImported,
            unitNames: plan.unitNames,
            unitSummaries: unitSummaries,
            skippedRowDetails: plan.skippedRowDetails,
            errors: errors,
            glyphWarnings: plan.glyphWarnings,
            importedCardIDs: importedCardIDs,
            dictionaryLookupRows: plan.dictionaryLookupRows,
            dictionaryLookupTermsByCardID: dictionaryLookupTermsByCardID
        )

        let batch = ImportBatchMO(context: context)
        batch.id = UUID()
        batch.fileName = summary.fileName
        batch.importedAt = Date()
        batch.totalRows = Int32(summary.totalRows)
        batch.importedRows = Int32(summary.importedRows)
        batch.skippedRows = Int32(summary.skippedRows)
        batch.errorsSummary = (summary.errors + summary.glyphWarnings).isEmpty ? nil : (summary.errors + summary.glyphWarnings).joined(separator: "\n")
        batch.notebook = notebook

        notebook.updatedAt = Date()
        return summary
    }

    private func analyze(
        url: URL,
        existingPairs: Set<CardPair>,
        mediaURLs: [URL]
    ) throws -> CSVImportPlan {
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
        let mediaByFileName = mediaFilesByFileName(from: mediaURLs)

        var seenPairs = existingPairs
        var importRows: [CSVImportRow] = []
        var duplicateRows = 0
        var invalidRows = 0
        var errors: [String] = []
        var skippedRowDetails: [String] = []
        var audioWarnings: [String] = []
        var glyphWarnings: [String] = []
        var missingAudioFiles = Set<String>()
        var unsupportedAudioFiles = Set<String>()

        for (index, row) in bodyRows.enumerated() {
            let sourceLine = index + 1 + (mapping.hasHeader ? 1 : 0)
            guard row.count >= 2 else {
                errors.append("Line \(sourceLine): expected at least two columns.")
                invalidRows += 1
                continue
            }

            let front = mapping.front(from: row) ?? ""
            let back = mapping.back(from: row) ?? ""
            let dictionaryLookupTerm = mapping.dictionaryLookupTerm(from: row)
            guard !front.isEmpty, !back.isEmpty || dictionaryLookupTerm != nil else {
                errors.append("Line \(sourceLine): front and back must both be non-empty unless a CZYZD lookup column is provided.")
                invalidRows += 1
                continue
            }

            glyphWarnings.append(contentsOf: GlyphDiagnostics.importWarnings(front: front, back: back, sourceLine: sourceLine))

            let pair = CardPair(front: front, back: back)
            guard !seenPairs.contains(pair) else {
                duplicateRows += 1
                skippedRowDetails.append("Line \(sourceLine): duplicate front/back pair skipped.")
                continue
            }

            let audioNames = mapping.audioFileNames(from: row)
            let frontAudioFileName = usableAudioFileName(
                audioNames.front,
                sourceLine: sourceLine,
                mediaByFileName: mediaByFileName,
                warnings: &audioWarnings,
                missingAudioFiles: &missingAudioFiles,
                unsupportedAudioFiles: &unsupportedAudioFiles
            )
            let backAudioFileName = usableAudioFileName(
                audioNames.back,
                sourceLine: sourceLine,
                mediaByFileName: mediaByFileName,
                warnings: &audioWarnings,
                missingAudioFiles: &missingAudioFiles,
                unsupportedAudioFiles: &unsupportedAudioFiles
            )
            importRows.append(CSVImportRow(
                sourceLine: sourceLine,
                front: front,
                back: back,
                unitName: mapping.unitName(from: row),
                frontAudioFileName: frontAudioFileName,
                backAudioFileName: backAudioFileName,
                dictionaryLookupTerm: dictionaryLookupTerm
            ))
            seenPairs.insert(pair)
        }

        return CSVImportPlan(
            fileName: url.lastPathComponent,
            totalRows: bodyRows.count,
            rows: importRows,
            invalidRows: invalidRows,
            duplicateRows: duplicateRows,
            errors: errors,
            skippedRowDetails: skippedRowDetails,
            audioWarnings: audioWarnings,
            glyphWarnings: glyphWarnings,
            dictionaryLookupRows: importRows.filter { $0.dictionaryLookupTerm != nil }.count,
            missingAudioFiles: missingAudioFiles.sorted(),
            unsupportedAudioFiles: unsupportedAudioFiles.sorted()
        )
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

    private func usableAudioFileName(
        _ fileName: String?,
        sourceLine: Int,
        mediaByFileName: [String: URL],
        warnings: inout [String],
        missingAudioFiles: inout Set<String>,
        unsupportedAudioFiles: inout Set<String>
    ) -> String? {
        guard let fileName else {
            return nil
        }

        let cleanName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            return nil
        }

        let lookupName = URL(fileURLWithPath: cleanName).lastPathComponent
        guard AudioFileStore.supportedExtensions.contains(URL(fileURLWithPath: lookupName).pathExtension.lowercased()) else {
            unsupportedAudioFiles.insert(lookupName)
            appendUnique(
                "Line \(sourceLine): \(AudioFileStoreError.unsupportedFormat(lookupName).localizedDescription)",
                to: &warnings
            )
            return nil
        }

        guard mediaByFileName[lookupName] != nil else {
            missingAudioFiles.insert(lookupName)
            appendUnique(
                "Line \(sourceLine): \(AudioFileStoreError.missingFile(lookupName).localizedDescription)",
                to: &warnings
            )
            return nil
        }

        return lookupName
    }

    private func appendUnique(_ message: String, to messages: inout [String]) {
        guard !messages.contains(message) else {
            return
        }
        messages.append(message)
    }

    private func existingCardPairs(in notebook: NotebookMO, context: NSManagedObjectContext) throws -> Set<CardPair> {
        let request = FlashcardMO.fetchRequest()
        request.predicate = NSPredicate(format: "notebook == %@", notebook)
        request.propertiesToFetch = ["front", "back"]
        return Set(try context.fetch(request).map { CardPair(front: $0.front, back: $0.back) })
    }

    private func mediaFilesByFileName(from urls: [URL]) -> [String: URL] {
        urls.reduce(into: [String: URL]()) { result, url in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                return
            }

            if isDirectory.boolValue {
                guard let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    return
                }

                for case let fileURL as URL in enumerator {
                    guard AudioFileStore.isSupportedAudioFile(fileURL) else {
                        continue
                    }
                    result[fileURL.lastPathComponent] = fileURL
                }
            } else if AudioFileStore.isSupportedAudioFile(url) {
                result[url.lastPathComponent] = url
            }
        }
    }

    private func startAccessing(urls: [URL]) -> [URL] {
        urls.filter { $0.startAccessingSecurityScopedResource() }
    }

    private func stopAccessing(_ urls: [URL]) {
        urls.forEach { $0.stopAccessingSecurityScopedResource() }
    }
}

private struct CSVImportPlan {
    let fileName: String
    let totalRows: Int
    let rows: [CSVImportRow]
    let invalidRows: Int
    let duplicateRows: Int
    let errors: [String]
    let skippedRowDetails: [String]
    let audioWarnings: [String]
    let glyphWarnings: [String]
    let dictionaryLookupRows: Int
    let missingAudioFiles: [String]
    let unsupportedAudioFiles: [String]

    var skippedRows: Int {
        invalidRows + duplicateRows
    }

    var preview: ImportPreview {
        ImportPreview(
            fileName: fileName,
            totalRows: totalRows,
            importableRows: rows.count,
            skippedRows: skippedRows,
            duplicateRows: duplicateRows,
            units: unitNames,
            missingAudioFiles: missingAudioFiles,
            unsupportedAudioFiles: unsupportedAudioFiles,
            skippedRowDetails: skippedRowDetails,
            errors: errors,
            audioWarnings: audioWarnings,
            glyphWarnings: glyphWarnings,
            dictionaryLookupRows: dictionaryLookupRows
        )
    }

    var unitNames: [String] {
        Array(Set(rows.map { NotebookUnitMO.normalizedUnitName($0.unitName) })).sorted()
    }
}

private struct CSVImportRow {
    let sourceLine: Int
    let front: String
    let back: String
    let unitName: String?
    let frontAudioFileName: String?
    let backAudioFileName: String?
    let dictionaryLookupTerm: String?
}

private struct CSVColumnMapping {
    let bodyRows: [[String]]
    let hasHeader: Bool
    private let frontAudioIndex: Int?
    private let backAudioIndex: Int?
    private let sharedAudioIndex: Int?
    private let unitIndex: Int?
    private let dictionaryLookupIndex: Int?
    private let frontIndex: Int
    private let backIndex: Int

    init(rows: [[String]]) {
        guard let first = rows.first, first.count >= 2 else {
            bodyRows = rows
            hasHeader = false
            frontIndex = 0
            backIndex = 1
            frontAudioIndex = rows.first?.indices.contains(2) == true ? 2 : nil
            backAudioIndex = rows.first?.indices.contains(3) == true ? 3 : nil
            sharedAudioIndex = nil
            unitIndex = nil
            dictionaryLookupIndex = nil
            return
        }

        let normalized = first.map(Self.normalizedHeader)
        if let headerFrontIndex = normalized.firstIndex(where: Self.frontHeaderNames.contains),
           let headerBackIndex = normalized.firstIndex(where: Self.backHeaderNames.contains) {
            bodyRows = Array(rows.dropFirst())
            hasHeader = true
            frontIndex = headerFrontIndex
            backIndex = headerBackIndex
            frontAudioIndex = normalized.firstIndex { Self.frontAudioHeaderNames.contains($0) }
            backAudioIndex = normalized.firstIndex { Self.backAudioHeaderNames.contains($0) }
            sharedAudioIndex = normalized.firstIndex { Self.sharedAudioHeaderNames.contains($0) }
            unitIndex = normalized.firstIndex { Self.unitHeaderNames.contains($0) }
            dictionaryLookupIndex = normalized.firstIndex { Self.dictionaryLookupHeaderNames.contains($0) }
        } else {
            bodyRows = rows
            hasHeader = false
            frontIndex = 0
            backIndex = 1
            frontAudioIndex = first.indices.contains(2) ? 2 : nil
            backAudioIndex = first.indices.contains(3) ? 3 : nil
            sharedAudioIndex = first.indices.contains(2) && !first.indices.contains(3) ? 2 : nil
            unitIndex = nil
            dictionaryLookupIndex = nil
        }
    }

    func front(from row: [String]) -> String? {
        row.indices.contains(frontIndex) ? row[frontIndex].trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }

    func back(from row: [String]) -> String? {
        row.indices.contains(backIndex) ? row[backIndex].trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }

    func unitName(from row: [String]) -> String? {
        unitIndex.flatMap { row.indices.contains($0) ? row[$0] : nil }
    }

    func dictionaryLookupTerm(from row: [String]) -> String? {
        guard let dictionaryLookupIndex,
              row.indices.contains(dictionaryLookupIndex) else {
            return nil
        }

        let term = row[dictionaryLookupIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty ? nil : term
    }

    func audioFileNames(from row: [String]) -> (front: String?, back: String?) {
        if let sharedAudioIndex, row.indices.contains(sharedAudioIndex), sharedAudioIndex != unitIndex {
            let shared = row[sharedAudioIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            return (shared, shared)
        }

        let front = frontAudioIndex.flatMap { row.indices.contains($0) ? row[$0].trimmingCharacters(in: .whitespacesAndNewlines) : nil }
        let back = backAudioIndex.flatMap { row.indices.contains($0) ? row[$0].trimmingCharacters(in: .whitespacesAndNewlines) : nil }
        return (front, back)
    }

    private static let frontHeaderNames: Set<String> = [
        "front", "question", "prompt", "term", "word", "hanzi", "chinese",
        "正面", "问题", "题目", "词", "单词", "汉字", "中文"
    ]

    private static let backHeaderNames: Set<String> = [
        "back", "answer", "definition", "meaning", "reading", "pronunciation",
        "背面", "答案", "解释", "释义", "意思", "读音", "发音"
    ]

    private static let frontAudioHeaderNames: Set<String> = [
        "frontaudio", "front_audio", "front audio", "frontsound", "front_sound",
        "正面音频", "正面声音"
    ]

    private static let backAudioHeaderNames: Set<String> = [
        "backaudio", "back_audio", "back audio", "backsound", "back_sound",
        "背面音频", "背面声音"
    ]

    private static let sharedAudioHeaderNames: Set<String> = [
        "audio", "audiofilename", "audio_file", "audio file", "sound",
        "音频", "声音"
    ]

    private static let unitHeaderNames: Set<String> = [
        "unit", "unitname", "unit_name", "unit name", "unitnumber", "unit_number", "unit number",
        "单元", "章节", "课", "课次"
    ]

    private static let dictionaryLookupHeaderNames: Set<String> = [
        "czyzd", "dictionary", "dictionarylookup", "dictionary_lookup", "lookup", "lookupterm", "lookup_term",
        "查词", "词典", "字典", "潮汕词典", "潮语词典"
    ]

    private static func normalizedHeader(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
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
                case "\n", "\r\n":
                    row.append(field)
                    append(row: row, to: &rows)
                    row = []
                    field = ""
                case "\r":
                    row.append(field)
                    append(row: row, to: &rows)
                    row = []
                    field = ""
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
