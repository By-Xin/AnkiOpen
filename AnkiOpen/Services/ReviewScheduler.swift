import CoreData
import Foundation

struct ReviewResult {
    let card: FlashcardMO
    let reviewLog: ReviewLogMO
    let previousDueAt: Date
    let nextDueAt: Date
}

enum ReviewSchedulerError: LocalizedError {
    case unsupportedRating

    var errorDescription: String? {
        switch self {
        case .unsupportedRating:
            return "不支持的复习评分。"
        }
    }
}

final class ReviewScheduler {
    private let fsrs = FSRS6Scheduler()

    func review(
        card: FlashcardMO,
        rating: ReviewRating,
        reviewedAt: Date = Date(),
        context: NSManagedObjectContext
    ) throws -> ReviewResult {
        let previousDueAt = card.dueAt
        let schedule = fsrs.review(card: card, rating: rating, reviewedAt: reviewedAt)

        card.dueAt = schedule.dueAt
        card.stability = schedule.stability
        card.difficulty = schedule.difficulty
        card.elapsedDays = schedule.elapsedDays
        card.scheduledDays = schedule.scheduledDays
        card.reps = schedule.reps
        card.lapses = schedule.lapses
        card.state = schedule.state.rawValue
        card.lastReviewAt = schedule.lastReviewAt

        card.updatedAt = reviewedAt

        let log = ReviewLogMO(context: context)
        log.id = UUID()
        log.card = card
        log.reviewedAt = reviewedAt
        log.rating = rating.rawValue
        log.previousDueAt = previousDueAt
        log.nextDueAt = card.dueAt

        return ReviewResult(card: card, reviewLog: log, previousDueAt: previousDueAt, nextDueAt: card.dueAt)
    }
}
