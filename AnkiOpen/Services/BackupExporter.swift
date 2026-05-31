import CoreData
import Foundation

struct BackupEnvelope: Codable, Equatable {
    let schemaVersion: Int
    let exportedAt: Date
    let notebooks: [BackupNotebook]
}

struct BackupNotebook: Codable, Equatable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let units: [BackupUnit]
}

struct BackupUnit: Codable, Equatable {
    let id: UUID
    let name: String
    let sortIndex: Int32
    let createdAt: Date
    let updatedAt: Date
    let flashcards: [BackupFlashcard]
}

struct BackupFlashcard: Codable, Equatable {
    let id: UUID
    let front: String
    let back: String
    let frontAudioFileName: String?
    let backAudioFileName: String?
    let createdAt: Date
    let updatedAt: Date
    let isArchived: Bool
    let dueAt: Date
    let stability: Double
    let difficulty: Double
    let elapsedDays: Double
    let scheduledDays: Double
    let learningSteps: Int16
    let reps: Int32
    let lapses: Int32
    let state: Int16
    let lastReviewAt: Date?
    let reviewLogs: [BackupReviewLog]
}

struct BackupReviewLog: Codable, Equatable {
    let id: UUID
    let reviewedAt: Date
    let rating: Int16
    let previousDueAt: Date
    let nextDueAt: Date
}

enum BackupExporterError: LocalizedError {
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .writeFailed:
            return "The backup file could not be written."
        }
    }
}

final class BackupExporter {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    func export(context: NSManagedObjectContext, exportedAt: Date = Date()) throws -> BackupEnvelope {
        let request = NotebookMO.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \NotebookMO.name, ascending: true),
            NSSortDescriptor(keyPath: \NotebookMO.createdAt, ascending: true)
        ]

        let notebooks = try context.fetch(request).map { notebook in
            BackupNotebook(
                id: notebook.id,
                name: notebook.name,
                createdAt: notebook.createdAt,
                updatedAt: notebook.updatedAt,
                units: backupUnits(for: notebook)
            )
        }

        return BackupEnvelope(schemaVersion: 2, exportedAt: exportedAt, notebooks: notebooks)
    }

    func writeBackup(context: NSManagedObjectContext, exportedAt: Date = Date()) throws -> URL {
        let envelope = try export(context: context, exportedAt: exportedAt)
        let data = try encoder.encode(envelope)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(for: exportedAt))

        do {
            try data.write(to: fileURL, options: [.atomic])
            return fileURL
        } catch {
            throw BackupExporterError.writeFailed
        }
    }

    private func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "AnkiOpen-Backup-\(formatter.string(from: date)).json"
    }

    private func backupUnits(for notebook: NotebookMO) -> [BackupUnit] {
        let existingUnits = notebook.units.sorted {
            if $0.sortIndex == $1.sortIndex {
                return $0.createdAt < $1.createdAt
            }
            return $0.sortIndex < $1.sortIndex
        }

        var backupUnits = existingUnits.map { unit in
            BackupUnit(
                id: unit.id,
                name: unit.name,
                sortIndex: unit.sortIndex,
                createdAt: unit.createdAt,
                updatedAt: unit.updatedAt,
                flashcards: backupFlashcards(Array(unit.flashcards))
            )
        }

        let orphanedCards = notebook.flashcards.filter { $0.unit == nil }
        if !orphanedCards.isEmpty {
            backupUnits.append(
                BackupUnit(
                    id: UUID(),
                    name: NotebookUnitMO.defaultName,
                    sortIndex: Int32(backupUnits.count),
                    createdAt: notebook.createdAt,
                    updatedAt: notebook.updatedAt,
                    flashcards: backupFlashcards(Array(orphanedCards))
                )
            )
        }

        return backupUnits
    }

    private func backupFlashcards(_ flashcards: [FlashcardMO]) -> [BackupFlashcard] {
        flashcards
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.front < $1.front
                }
                return $0.createdAt < $1.createdAt
            }
            .map { card in
                BackupFlashcard(
                    id: card.id,
                    front: card.front,
                    back: card.back,
                    frontAudioFileName: card.frontAudioFileName,
                    backAudioFileName: card.backAudioFileName,
                    createdAt: card.createdAt,
                    updatedAt: card.updatedAt,
                    isArchived: card.isArchived,
                    dueAt: card.dueAt,
                    stability: card.stability,
                    difficulty: card.difficulty,
                    elapsedDays: card.elapsedDays,
                    scheduledDays: card.scheduledDays,
                    learningSteps: card.learningSteps,
                    reps: card.reps,
                    lapses: card.lapses,
                    state: card.state,
                    lastReviewAt: card.lastReviewAt,
                    reviewLogs: backupReviewLogs(for: card)
                )
            }
    }

    private func backupReviewLogs(for card: FlashcardMO) -> [BackupReviewLog] {
        card.reviewLogs
            .sorted {
                if $0.reviewedAt == $1.reviewedAt {
                    return $0.rating < $1.rating
                }
                return $0.reviewedAt < $1.reviewedAt
            }
            .map { log in
                BackupReviewLog(
                    id: log.id,
                    reviewedAt: log.reviewedAt,
                    rating: log.rating,
                    previousDueAt: log.previousDueAt,
                    nextDueAt: log.nextDueAt
                )
            }
    }
}
