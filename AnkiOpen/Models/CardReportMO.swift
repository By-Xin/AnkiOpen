import CoreData
import Foundation

@objc(CardReportMO)
final class CardReportMO: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var category: String
    @NSManaged var note: String
    @NSManaged var createdAt: Date
    @NSManaged var resolvedAt: Date?
    @NSManaged var card: FlashcardMO
}

extension CardReportMO {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CardReportMO> {
        NSFetchRequest<CardReportMO>(entityName: "CardReport")
    }

    static func insert(
        card: FlashcardMO,
        category: ReportCategory,
        note: String,
        context: NSManagedObjectContext
    ) -> CardReportMO {
        let report = CardReportMO(context: context)
        report.id = UUID()
        report.category = category.rawValue
        report.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        report.createdAt = Date()
        report.card = card
        return report
    }

    var isResolved: Bool {
        resolvedAt != nil
    }

    var categoryTitle: String {
        ReportCategory(rawValue: category)?.title ?? "Other"
    }

    func markResolved(at date: Date = Date()) {
        resolvedAt = date
    }

    func reopen() {
        resolvedAt = nil
    }
}

enum ReportCategory: String, CaseIterable, Identifiable {
    case audioMismatch
    case pronunciation
    case translation
    case typo
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .audioMismatch:
            return "Audio mismatch"
        case .pronunciation:
            return "Pronunciation / pinyin error"
        case .translation:
            return "Translation error"
        case .typo:
            return "Typo"
        case .other:
            return "Other"
        }
    }
}
