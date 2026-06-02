import CoreData
import Foundation

struct CZYZDDictionaryNotebookImportSummary: Equatable {
    let checkedTerms: Int
    let addedCards: Int
    let skippedCards: Int
    let failedTerms: Int
    let audioFilesAdded: Int
    let nextIndex: Int
    let messages: [String]

    var messageSummary: String? {
        messages.isEmpty ? nil : messages.joined(separator: "\n")
    }
}

protocol CZYZDDictionaryAudioDownloading {
    func downloadAudio(from url: URL, term: String) async throws -> CZYZDAudioDownload
}

final class CZYZDDictionaryAudioDownloader: CZYZDDictionaryAudioDownloading {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func downloadAudio(from url: URL, term: String) async throws -> CZYZDAudioDownload {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("http://www.czyzd.com/", forHTTPHeaderField: "Referer")
        request.setValue("AnkiOpen/0.1 CZYZD Dictionary Import", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              !data.isEmpty else {
            throw CZYZDAudioResolverError.invalidAudioResponse
        }

        let pathExtension = url.pathExtension.isEmpty ? "mp3" : url.pathExtension
        return CZYZDAudioDownload(
            data: data,
            suggestedFileName: "\(Self.safeFileStem(for: term)).\(pathExtension)"
        )
    }

    private static func safeFileStem(for term: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let clean = term
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
        let stem = String(clean).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return stem.isEmpty ? "czyzd-audio" : stem
    }
}

@MainActor
final class CZYZDDictionaryNotebookBuilder {
    static let defaultNotebookName = "潮语词典"
    static let defaultUnitName = "常用字"

    private let lookup: CZYZDDictionaryLookingUp
    private let audioDownloader: CZYZDDictionaryAudioDownloading

    init(
        lookup: CZYZDDictionaryLookingUp = CZYZDDictionaryLookup(),
        audioDownloader: CZYZDDictionaryAudioDownloading = CZYZDDictionaryAudioDownloader()
    ) {
        self.lookup = lookup
        self.audioDownloader = audioDownloader
    }

    func addEntry(
        _ entry: CZYZDDictionaryEntry,
        toNewNotebookNamed notebookName: String,
        context: NSManagedObjectContext
    ) async throws -> CZYZDDictionaryNotebookImportSummary {
        let notebook = createNotebook(named: notebookName, context: context)
        let unit = NotebookUnitMO.findOrCreate(named: Self.defaultUnitName, in: notebook, context: context)
        return try await addEntry(entry, toUnit: unit, context: context)
    }

    func addEntry(
        _ entry: CZYZDDictionaryEntry,
        toExistingNotebook notebook: NotebookMO,
        unitName: String?,
        context: NSManagedObjectContext
    ) async throws -> CZYZDDictionaryNotebookImportSummary {
        let back = Self.cardBackText(from: entry)
        guard !entry.term.trimmed.isEmpty, !back.isEmpty else {
            return CZYZDDictionaryNotebookImportSummary(
                checkedTerms: 1,
                addedCards: 0,
                skippedCards: 1,
                failedTerms: 0,
                audioFilesAdded: 0,
                nextIndex: 0,
                messages: ["\(entry.term) is missing usable dictionary text."]
            )
        }
        guard !containsCard(front: entry.term, back: back, in: notebook, context: context) else {
            return CZYZDDictionaryNotebookImportSummary(
                checkedTerms: 1,
                addedCards: 0,
                skippedCards: 1,
                failedTerms: 0,
                audioFilesAdded: 0,
                nextIndex: 0,
                messages: ["\(entry.term) already exists in \(notebook.name)."]
            )
        }

        let unit = NotebookUnitMO.findOrCreate(named: unitName, in: notebook, context: context)
        return try await addEntry(entry, toUnit: unit, context: context)
    }

    func importCommonTerms(
        intoNotebookNamed notebookName: String,
        startingAt startIndex: Int,
        limit: Int,
        context: NSManagedObjectContext
    ) async -> CZYZDDictionaryNotebookImportSummary {
        let terms = Self.commonCharacterTerms
        let start = max(0, min(startIndex, terms.count))
        let end = min(start + max(1, limit), terms.count)
        guard start < end else {
            return CZYZDDictionaryNotebookImportSummary(
                checkedTerms: 0,
                addedCards: 0,
                skippedCards: 0,
                failedTerms: 0,
                audioFilesAdded: 0,
                nextIndex: terms.count,
                messages: ["内置常用词已经全部检查完。"]
            )
        }

        let notebook = findOrCreateNotebook(named: notebookName, context: context)
        let unit = NotebookUnitMO.findOrCreate(named: Self.defaultUnitName, in: notebook, context: context)

        var added = 0
        var skipped = 0
        var failed = 0
        var audioAdded = 0
        var messages: [String] = []

        for term in terms[start..<end] {
            do {
                guard let entry = try await lookup.lookup(term: term).first else {
                    failed += 1
                    if messages.count < 8 {
                        messages.append("潮语词典没有找到 \(term)。")
                    }
                    continue
                }

                let result = await addCardIfNeeded(entry: entry, unit: unit, context: context)
                if result.didAdd {
                    added += 1
                    if result.didAttachAudio {
                        audioAdded += 1
                    }
                } else {
                    skipped += 1
                }
                if let message = result.message, messages.count < 8 {
                    messages.append(message)
                }
            } catch {
                failed += 1
                if messages.count < 8 {
                    messages.append("\(term): \(error.localizedDescription)")
                }
            }
        }

        do {
            if context.hasChanges {
                notebook.updatedAt = Date()
                unit.updatedAt = Date()
                try context.save()
            }
        } catch {
            messages.append("无法保存词典笔记本。")
        }

        return CZYZDDictionaryNotebookImportSummary(
            checkedTerms: end - start,
            addedCards: added,
            skippedCards: skipped,
            failedTerms: failed,
            audioFilesAdded: audioAdded,
            nextIndex: end,
            messages: messages
        )
    }

    private func createNotebook(named rawName: String, context: NSManagedObjectContext) -> NotebookMO {
        let now = Date()
        let notebook = NotebookMO(context: context)
        notebook.id = UUID()
        notebook.name = normalizedNotebookName(rawName)
        notebook.createdAt = now
        notebook.updatedAt = now
        return notebook
    }

    private func findOrCreateNotebook(named rawName: String, context: NSManagedObjectContext) -> NotebookMO {
        let name = normalizedNotebookName(rawName)
        let request = NotebookMO.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "name ==[c] %@", name)

        if let existing = try? context.fetch(request).first {
            return existing
        }
        return createNotebook(named: name, context: context)
    }

    private func addCardIfNeeded(
        entry: CZYZDDictionaryEntry,
        unit: NotebookUnitMO,
        context: NSManagedObjectContext
    ) async -> DictionaryCardInsertResult {
        let back = Self.cardBackText(from: entry)
        guard !entry.term.trimmed.isEmpty, !back.isEmpty else {
            return DictionaryCardInsertResult(didAdd: false, didAttachAudio: false, message: "\(entry.term) is missing usable dictionary text.")
        }

        if containsCard(front: entry.term, back: back, in: unit.notebook, context: context) {
            return DictionaryCardInsertResult(didAdd: false, didAttachAudio: false, message: "\(entry.term) already exists in \(unit.notebook.name).")
        }

        let card = FlashcardMO.insert(front: entry.term, back: back, unit: unit, context: context)
        var didAttachAudio = false
        var message: String?

        if let audioURL = entry.audioURL {
            do {
                let download = try await audioDownloader.downloadAudio(from: audioURL, term: entry.term)
                let storedFileName = try AudioFileStore.storeDownloadedAudio(
                    data: download.data,
                    suggestedFileName: download.suggestedFileName
                )
                card.frontAudioFileName = storedFileName
                card.backAudioFileName = storedFileName
                card.updatedAt = Date()
                didAttachAudio = true
            } catch {
                message = "\(entry.term): could not attach CZYZD audio (\(error.localizedDescription))"
            }
        }

        unit.updatedAt = Date()
        unit.notebook.updatedAt = Date()
        return DictionaryCardInsertResult(didAdd: true, didAttachAudio: didAttachAudio, message: message)
    }

    private func addEntry(
        _ entry: CZYZDDictionaryEntry,
        toUnit unit: NotebookUnitMO,
        context: NSManagedObjectContext
    ) async throws -> CZYZDDictionaryNotebookImportSummary {
        let result = await addCardIfNeeded(entry: entry, unit: unit, context: context)
        try context.save()

        return CZYZDDictionaryNotebookImportSummary(
            checkedTerms: 1,
            addedCards: result.didAdd ? 1 : 0,
            skippedCards: result.didAdd ? 0 : 1,
            failedTerms: 0,
            audioFilesAdded: result.didAttachAudio ? 1 : 0,
            nextIndex: 0,
            messages: result.message.map { [$0] } ?? []
        )
    }

    private func containsCard(
        front: String,
        back: String,
        in notebook: NotebookMO,
        context: NSManagedObjectContext
    ) -> Bool {
        let request = FlashcardMO.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "notebook == %@ AND front == %@ AND back == %@ AND isArchived == NO",
            notebook,
            front,
            back
        )
        return ((try? context.count(for: request)) ?? 0) > 0
    }

    private func normalizedNotebookName(_ rawName: String) -> String {
        let trimmed = rawName.trimmed
        return trimmed.isEmpty ? Self.defaultNotebookName : trimmed
    }

    static func cardBackText(from entry: CZYZDDictionaryEntry) -> String {
        return [
            entry.chaopin.trimmed.isEmpty ? "" : "潮拼: \(entry.chaopin.trimmed)",
            entry.definition.trimmed.isEmpty ? "" : "解释: \(entry.definition.trimmed)"
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    static let commonCharacterTerms: [String] = Array(
        "的一是在不了有人和国中大为上个到说们地出道也时年得就那要下以生会自着去之过家学对可她里后小么心多天而能好都然没日于起还发成事只作当想看文无开手十用主行方又如前所本见经头面公同三已老从动两长知民样现分将外但身些与高意进把法此实回二理美点月明其种声全工己话儿者向情部正名定女问力机给等几很业最间新什打便位因重被走电四第门相次东西政海口使教先真听世气信北少关并内加化由却代军产入光制件别许先花今再"
    ).map(String.init)
}

private struct DictionaryCardInsertResult {
    let didAdd: Bool
    let didAttachAudio: Bool
    let message: String?
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
