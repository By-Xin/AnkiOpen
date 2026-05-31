import CoreData
import Foundation

struct BackupImportSummary: Equatable {
    let fileName: String
    let importedNotebooks: Int
    let importedUnits: Int
    let importedCards: Int
    let importedReviewLogs: Int
    let importedMediaFiles: Int
    let skippedDuplicates: Int
}

enum BackupImporterError: LocalizedError {
    case unreadableFile
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "The selected backup file could not be read."
        case .unsupportedSchema(let version):
            return "Backup schema version \(version) is not supported."
        }
    }
}

final class BackupImporter {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func `import`(url: URL, context: NSManagedObjectContext) throws -> BackupImportSummary {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else {
            throw BackupImporterError.unreadableFile
        }

        let envelope = try decoder.decode(BackupEnvelope.self, from: data)
        guard [2, 3].contains(envelope.schemaVersion) else {
            throw BackupImporterError.unsupportedSchema(envelope.schemaVersion)
        }

        return try importEnvelope(envelope, fileName: url.lastPathComponent, context: context)
    }

    func importEnvelope(
        _ envelope: BackupEnvelope,
        fileName: String = "Backup.json",
        context: NSManagedObjectContext
    ) throws -> BackupImportSummary {
        guard [2, 3].contains(envelope.schemaVersion) else {
            throw BackupImporterError.unsupportedSchema(envelope.schemaVersion)
        }

        var importedNotebooks = 0
        var importedUnits = 0
        var importedCards = 0
        var importedReviewLogs = 0
        var importedMediaFiles = 0
        var skippedDuplicates = 0

        for mediaFile in envelope.mediaFiles {
            try AudioFileStore.restoreAudio(storedFileName: mediaFile.storedFileName, data: mediaFile.data)
            importedMediaFiles += 1
        }

        for backupNotebook in envelope.notebooks {
            let notebookResult = try findOrCreateNotebook(backupNotebook, context: context)
            importedNotebooks += notebookResult.didCreate ? 1 : 0
            skippedDuplicates += notebookResult.didCreate ? 0 : 1

            for backupUnit in backupNotebook.units {
                let unitResult = try findOrCreateUnit(backupUnit, notebook: notebookResult.notebook, context: context)
                importedUnits += unitResult.didCreate ? 1 : 0
                skippedDuplicates += unitResult.didCreate ? 0 : 1

                for backupCard in backupUnit.flashcards {
                    let cardResult = try findOrCreateCard(
                        backupCard,
                        unit: unitResult.unit,
                        context: context
                    )
                    importedCards += cardResult.didCreate ? 1 : 0
                    skippedDuplicates += cardResult.didCreate ? 0 : 1
                    let reviewLogResult = mergeReviewLogs(
                        backupCard.reviewLogs,
                        into: cardResult.card,
                        context: context
                    )
                    importedReviewLogs += reviewLogResult.imported
                    skippedDuplicates += reviewLogResult.skipped
                }
            }
        }

        return BackupImportSummary(
            fileName: fileName,
            importedNotebooks: importedNotebooks,
            importedUnits: importedUnits,
            importedCards: importedCards,
            importedReviewLogs: importedReviewLogs,
            importedMediaFiles: importedMediaFiles,
            skippedDuplicates: skippedDuplicates
        )
    }

    private func findOrCreateNotebook(
        _ backup: BackupNotebook,
        context: NSManagedObjectContext
    ) throws -> (notebook: NotebookMO, didCreate: Bool) {
        if let existing = try fetchNotebook(id: backup.id, name: backup.name, context: context) {
            return (existing, false)
        }

        let notebook = NotebookMO(context: context)
        notebook.id = backup.id
        notebook.name = backup.name
        notebook.createdAt = backup.createdAt
        notebook.updatedAt = backup.updatedAt
        return (notebook, true)
    }

    private func findOrCreateUnit(
        _ backup: BackupUnit,
        notebook: NotebookMO,
        context: NSManagedObjectContext
    ) throws -> (unit: NotebookUnitMO, didCreate: Bool) {
        if let existing = try fetchUnit(id: backup.id, name: backup.name, notebook: notebook, context: context) {
            return (existing, false)
        }

        let unit = NotebookUnitMO(context: context)
        unit.id = backup.id
        unit.name = backup.name
        unit.sortIndex = backup.sortIndex
        unit.createdAt = backup.createdAt
        unit.updatedAt = backup.updatedAt
        unit.notebook = notebook
        return (unit, true)
    }

    private func findOrCreateCard(
        _ backup: BackupFlashcard,
        unit: NotebookUnitMO,
        context: NSManagedObjectContext
    ) throws -> (card: FlashcardMO, didCreate: Bool) {
        if let existing = try fetchCard(id: backup.id, front: backup.front, back: backup.back, unit: unit, context: context) {
            return (existing, false)
        }

        let card = FlashcardMO(context: context)
        card.id = backup.id
        card.front = backup.front
        card.back = backup.back
        card.frontAudioFileName = backup.frontAudioFileName
        card.backAudioFileName = backup.backAudioFileName
        card.createdAt = backup.createdAt
        card.updatedAt = backup.updatedAt
        card.isArchived = backup.isArchived
        card.dueAt = backup.dueAt
        card.stability = backup.stability
        card.difficulty = backup.difficulty
        card.elapsedDays = backup.elapsedDays
        card.scheduledDays = backup.scheduledDays
        card.learningSteps = backup.learningSteps
        card.reps = backup.reps
        card.lapses = backup.lapses
        card.state = backup.state
        card.lastReviewAt = backup.lastReviewAt
        card.notebook = unit.notebook
        card.unit = unit
        return (card, true)
    }

    private func mergeReviewLogs(
        _ backupLogs: [BackupReviewLog],
        into card: FlashcardMO,
        context: NSManagedObjectContext
    ) -> (imported: Int, skipped: Int) {
        var existingIDs = Set(card.reviewLogs.map(\.id))
        var imported = 0
        var skipped = 0

        for backupLog in backupLogs {
            guard !existingIDs.contains(backupLog.id) else {
                skipped += 1
                continue
            }

            let log = ReviewLogMO(context: context)
            log.id = backupLog.id
            log.card = card
            log.reviewedAt = backupLog.reviewedAt
            log.rating = backupLog.rating
            log.previousDueAt = backupLog.previousDueAt
            log.nextDueAt = backupLog.nextDueAt
            existingIDs.insert(backupLog.id)
            imported += 1
        }

        return (imported, skipped)
    }

    private func fetchNotebook(id: UUID, name: String, context: NSManagedObjectContext) throws -> NotebookMO? {
        let request = NotebookMO.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "id == %@", id as CVarArg),
            NSPredicate(format: "name ==[c] %@", name)
        ])
        return try context.fetch(request).first
    }

    private func fetchUnit(
        id: UUID,
        name: String,
        notebook: NotebookMO,
        context: NSManagedObjectContext
    ) throws -> NotebookUnitMO? {
        let request = NotebookUnitMO.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "notebook == %@", notebook),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "id == %@", id as CVarArg),
                NSPredicate(format: "name ==[c] %@", name)
            ])
        ])
        return try context.fetch(request).first
    }

    private func fetchCard(
        id: UUID,
        front: String,
        back: String,
        unit: NotebookUnitMO,
        context: NSManagedObjectContext
    ) throws -> FlashcardMO? {
        let request = FlashcardMO.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "unit == %@", unit),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "id == %@", id as CVarArg),
                NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "front == %@", front),
                    NSPredicate(format: "back == %@", back)
                ])
            ])
        ])
        return try context.fetch(request).first
    }
}
