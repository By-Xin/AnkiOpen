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
    @NSManaged var correctionLogs: Set<CardCorrectionLogMO>
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
        ReportCategory(rawValue: category)?.title ?? "其他"
    }

    func markResolved(at date: Date = Date()) {
        resolvedAt = date
    }

    func reopen() {
        resolvedAt = nil
    }

    func matchesSearchText(_ searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return true
        }

        let searchableFields = [
            categoryTitle,
            note,
            card.front,
            card.back,
            card.notebook.name,
            card.unit?.name
        ].compactMap { $0 }

        return searchableFields.contains { field in
            field.localizedCaseInsensitiveContains(query)
        }
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
            return "音频不匹配"
        case .pronunciation:
            return "读音/拼音错误"
        case .translation:
            return "释义错误"
        case .typo:
            return "错别字"
        case .other:
            return "其他"
        }
    }
}

struct ReportCategoryCount: Equatable, Identifiable {
    let category: ReportCategory
    let count: Int

    var id: String {
        category.rawValue
    }

    var title: String {
        category.title
    }
}

struct ReportAnalytics: Equatable {
    let totalReports: Int
    let openReports: Int
    let resolvedReports: Int
    let correctionLogs: Int
    let openCategoryCounts: [ReportCategoryCount]
    let resolvedCategoryCounts: [ReportCategoryCount]

    init(reports: [CardReportMO]) {
        totalReports = reports.count
        openReports = reports.filter { !$0.isResolved }.count
        resolvedReports = reports.filter(\.isResolved).count
        correctionLogs = Set(reports.flatMap { $0.correctionLogs.map(\.id) }).count
        openCategoryCounts = Self.categoryCounts(for: reports.filter { !$0.isResolved })
        resolvedCategoryCounts = Self.categoryCounts(for: reports.filter(\.isResolved))
    }

    var hasReports: Bool {
        totalReports > 0
    }

    var leadingOpenCategory: ReportCategoryCount? {
        openCategoryCounts.first
    }

    var openCategorySummary: String {
        Self.summaryText(for: openCategoryCounts)
    }

    var resolvedCategorySummary: String {
        Self.summaryText(for: resolvedCategoryCounts)
    }

    private static func categoryCounts(for reports: [CardReportMO]) -> [ReportCategoryCount] {
        let countsByCategory = Dictionary(grouping: reports) { report in
            ReportCategory(rawValue: report.category) ?? .other
        }
        return ReportCategory.allCases.compactMap { category in
            guard let count = countsByCategory[category]?.count, count > 0 else {
                return nil
            }
            return ReportCategoryCount(category: category, count: count)
        }
        .sorted {
            if $0.count == $1.count {
                return $0.title < $1.title
            }
            return $0.count > $1.count
        }
    }

    private static func summaryText(for categoryCounts: [ReportCategoryCount]) -> String {
        guard !categoryCounts.isEmpty else {
            return "无"
        }
        return categoryCounts
            .map { "\($0.title) \($0.count)" }
            .joined(separator: "、")
    }
}

struct ReportListFilter: Equatable {
    let category: ReportCategory?
    let searchText: String

    init(category: ReportCategory? = nil, searchText: String = "") {
        self.category = category
        self.searchText = searchText
    }

    func matches(_ report: CardReportMO) -> Bool {
        if let category,
           ReportCategory(rawValue: report.category) != category {
            return false
        }

        return report.matchesSearchText(searchText)
    }
}
