import CoreData
import Foundation

@objc(NotebookMO)
final class NotebookMO: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var units: Set<NotebookUnitMO>
    @NSManaged var flashcards: Set<FlashcardMO>
    @NSManaged var importBatches: Set<ImportBatchMO>
}

extension NotebookMO {
    @nonobjc class func fetchRequest() -> NSFetchRequest<NotebookMO> {
        NSFetchRequest<NotebookMO>(entityName: "Notebook")
    }

    var activeCardsCount: Int {
        flashcards.filter { !$0.isArchived }.count
    }

    var archivedCardsCount: Int {
        flashcards.filter(\.isArchived).count
    }

    var missingAudioCardsCount: Int {
        flashcards.filter {
            !$0.isArchived && ($0.frontAudioFileName == nil || $0.backAudioFileName == nil)
        }.count
    }

    func dueCardsCount(at date: Date = Date()) -> Int {
        flashcards.filter {
            !$0.isArchived && $0.dueAt <= date
        }.count
    }

    var unitsCount: Int {
        units.count
    }
}

struct HomeDashboardMetrics: Equatable {
    let dueCards: Int
    let activeCards: Int
    let archivedCards: Int
    let missingAudioCards: Int
    let openReports: Int

    init(cards: [FlashcardMO], reports: [CardReportMO], at date: Date = Date()) {
        dueCards = cards.filter { !$0.isArchived && $0.dueAt <= date }.count
        activeCards = cards.filter { !$0.isArchived }.count
        archivedCards = cards.filter(\.isArchived).count
        missingAudioCards = cards.filter {
            !$0.isArchived && ($0.frontAudioFileName == nil || $0.backAudioFileName == nil)
        }.count
        openReports = reports.filter { !$0.isResolved }.count
    }
}
