import CoreData
import Foundation

@objc(ReviewLogMO)
final class ReviewLogMO: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var reviewedAt: Date
    @NSManaged var rating: Int16
    @NSManaged var previousDueAt: Date
    @NSManaged var nextDueAt: Date
    @NSManaged var card: FlashcardMO
}

extension ReviewLogMO {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ReviewLogMO> {
        NSFetchRequest<ReviewLogMO>(entityName: "ReviewLog")
    }
}
