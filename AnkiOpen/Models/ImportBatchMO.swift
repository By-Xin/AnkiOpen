import CoreData
import Foundation

@objc(ImportBatchMO)
final class ImportBatchMO: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var fileName: String
    @NSManaged var importedAt: Date
    @NSManaged var totalRows: Int32
    @NSManaged var importedRows: Int32
    @NSManaged var skippedRows: Int32
    @NSManaged var errorsSummary: String?
    @NSManaged var notebook: NotebookMO
}

extension ImportBatchMO {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ImportBatchMO> {
        NSFetchRequest<ImportBatchMO>(entityName: "ImportBatch")
    }
}
