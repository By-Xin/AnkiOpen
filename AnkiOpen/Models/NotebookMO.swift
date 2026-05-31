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

    var unitsCount: Int {
        units.count
    }
}
