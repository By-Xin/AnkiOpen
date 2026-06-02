import CoreData
import Foundation

struct CZYZDDictionaryNotebookImportSummary: Equatable {
    let checkedTerms: Int
    let addedCards: Int
    let skippedCards: Int
    let failedTerms: Int
    let nextIndex: Int
    let messages: [String]

    var messageSummary: String? {
        messages.isEmpty ? nil : messages.joined(separator: "\n")
    }
}

@MainActor
final class CZYZDDictionaryNotebookBuilder {
    static let defaultNotebookName = "CZYZD Dictionary"
    static let defaultUnitName = "Common Characters"

    private let lookup: CZYZDDictionaryLookingUp

    init(lookup: CZYZDDictionaryLookingUp = CZYZDDictionaryLookup()) {
        self.lookup = lookup
    }

    func addEntry(
        _ entry: CZYZDDictionaryEntry,
        toNewNotebookNamed notebookName: String,
        context: NSManagedObjectContext
    ) throws -> CZYZDDictionaryNotebookImportSummary {
        let notebook = createNotebook(named: notebookName, context: context)
        let unit = NotebookUnitMO.findOrCreate(named: Self.defaultUnitName, in: notebook, context: context)
        let didAdd = addCardIfNeeded(entry: entry, unit: unit, context: context)
        try context.save()

        return CZYZDDictionaryNotebookImportSummary(
            checkedTerms: 1,
            addedCards: didAdd ? 1 : 0,
            skippedCards: didAdd ? 0 : 1,
            failedTerms: 0,
            nextIndex: 0,
            messages: didAdd ? [] : ["\(entry.term) already exists in \(notebook.name)."]
        )
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
                nextIndex: terms.count,
                messages: ["All bundled common terms have already been checked."]
            )
        }

        let notebook = findOrCreateNotebook(named: notebookName, context: context)
        let unit = NotebookUnitMO.findOrCreate(named: Self.defaultUnitName, in: notebook, context: context)

        var added = 0
        var skipped = 0
        var failed = 0
        var messages: [String] = []

        for term in terms[start..<end] {
            do {
                guard let entry = try await lookup.lookup(term: term).first else {
                    failed += 1
                    if messages.count < 8 {
                        messages.append("No CZYZD entry found for \(term).")
                    }
                    continue
                }

                if addCardIfNeeded(entry: entry, unit: unit, context: context) {
                    added += 1
                } else {
                    skipped += 1
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
            messages.append("Could not save dictionary notebook.")
        }

        return CZYZDDictionaryNotebookImportSummary(
            checkedTerms: end - start,
            addedCards: added,
            skippedCards: skipped,
            failedTerms: failed,
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
    ) -> Bool {
        let back = Self.cardBackText(from: entry)
        guard !entry.term.trimmed.isEmpty, !back.isEmpty else {
            return false
        }

        if containsCard(front: entry.term, back: back, in: unit.notebook, context: context) {
            return false
        }

        _ = FlashcardMO.insert(front: entry.term, back: back, unit: unit, context: context)
        unit.updatedAt = Date()
        unit.notebook.updatedAt = Date()
        return true
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
        let chaoshanPronunciation = entry.chaopin.isEmpty ? entry.pronunciation : entry.chaopin
        return [
            chaoshanPronunciation.trimmed.isEmpty ? "" : "潮拼: \(chaoshanPronunciation.trimmed)",
            entry.definition.trimmed.isEmpty ? "" : "解释: \(entry.definition.trimmed)"
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    static let commonCharacterTerms: [String] = Array(
        "的一是在不了有人和国中大为上个到说们地出道也时年得就那要下以生会自着去之过家学对可她里后小么心多天而能好都然没日于起还发成事只作当想看文无开手十用主行方又如前所本见经头面公同三已老从动两长知民样现分将外但身些与高意进把法此实回二理美点月明其种声全工己话儿者向情部正名定女问力机给等几很业最间新什打便位因重被走电四第门相次东西政海口使教先真听世气信北少关并内加化由却代军产入光制件别许先花今再"
    ).map(String.init)
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
