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

    var ratingValue: ReviewRating? {
        ReviewRating(rawValue: rating)
    }

    var ratingTitle: String {
        ratingValue?.title ?? "未知"
    }
}

struct ReviewHistoryFilter {
    let searchText: String

    func matches(_ log: ReviewLogMO) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        guard !query.isEmpty else {
            return true
        }

        let fields = [
            log.card.front,
            log.card.back,
            log.card.notebook.name,
            log.card.unit?.name ?? "",
            log.ratingTitle
        ]

        return fields.contains { $0.localizedLowercase.contains(query) }
    }
}
