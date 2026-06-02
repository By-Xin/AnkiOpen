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
        flashcards.filter(\.needsAudioAttention).count
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
    let dueTomorrowCards: Int
    let futureDueCards: Int
    let activeCards: Int
    let archivedCards: Int
    let missingAudioCards: Int
    let rareGlyphCards: Int
    let newCards: Int
    let openReports: Int
    let reviewedToday: Int
    let reviewedLast7Days: Int

    var hasAttentionItems: Bool {
        missingAudioCards > 0 || openReports > 0
    }

    var hasMaintenanceItems: Bool {
        hasAttentionItems || rareGlyphCards > 0
    }

    init(
        cards: [FlashcardMO],
        reports: [CardReportMO],
        reviewLogs: [ReviewLogMO] = [],
        at date: Date = Date(),
        calendar: Calendar = .current
    ) {
        let active = cards.filter { !$0.isArchived }
        let todayStart = calendar.startOfDay(for: date)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart.addingTimeInterval(86_400)
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 1, to: tomorrowStart) ?? tomorrowStart.addingTimeInterval(86_400)

        dueCards = active.filter { $0.dueAt <= date }.count
        dueTomorrowCards = active.filter { $0.dueAt >= tomorrowStart && $0.dueAt < dayAfterTomorrow }.count
        futureDueCards = active.filter { $0.dueAt > date }.count
        activeCards = active.count
        archivedCards = cards.filter(\.isArchived).count
        missingAudioCards = active.filter(\.needsAudioAttention).count
        rareGlyphCards = active.filter {
            GlyphDiagnostics.containsRiskyGlyphs($0.front + $0.back)
        }.count
        newCards = active.filter { $0.reps == 0 }.count
        openReports = reports.filter { !$0.isResolved }.count

        let startOfToday = calendar.startOfDay(for: date)
        let startOfSevenDayWindow = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        reviewedToday = reviewLogs.filter { $0.reviewedAt >= startOfToday && $0.reviewedAt <= date }.count
        reviewedLast7Days = reviewLogs.filter { $0.reviewedAt >= startOfSevenDayWindow && $0.reviewedAt <= date }.count
    }
}
