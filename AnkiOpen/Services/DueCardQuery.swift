import CoreData
import Foundation

enum DueCardQuery {
    static func fetchRequest(for notebook: NotebookMO?, at date: Date = Date()) -> NSFetchRequest<FlashcardMO> {
        let request = FlashcardMO.fetchRequest()
        if let notebook {
            request.predicate = NSPredicate(
                format: "notebook == %@ AND isArchived == NO AND dueAt <= %@",
                notebook,
                date as NSDate
            )
        } else {
            request.predicate = NSPredicate(format: "isArchived == NO AND dueAt <= %@", date as NSDate)
        }
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FlashcardMO.dueAt, ascending: true),
            NSSortDescriptor(keyPath: \FlashcardMO.createdAt, ascending: true)
        ]
        return request
    }

    static func forNotebook(_ notebook: NotebookMO?, at date: Date = Date(), context: NSManagedObjectContext) throws -> [FlashcardMO] {
        try context.fetch(fetchRequest(for: notebook, at: date))
    }
}
