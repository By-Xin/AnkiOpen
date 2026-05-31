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
            return "Unsupported review rating."
        }
    }
}

final class ReviewScheduler {
    func review(
        card: FlashcardMO,
        rating: ReviewRating,
        reviewedAt: Date = Date(),
        context: NSManagedObjectContext
    ) throws -> ReviewResult {
        let previousDueAt = card.dueAt
        applyFallbackSchedule(card: card, rating: rating, reviewedAt: reviewedAt)

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

    private func applyFallbackSchedule(card: FlashcardMO, rating: ReviewRating, reviewedAt: Date) {
        let previousState = ReviewState(rawValue: card.state) ?? .new
        let elapsedDays = max(0, reviewedAt.timeIntervalSince(card.lastReviewAt ?? card.createdAt) / 86_400)
        let interval: TimeInterval

        switch rating {
        case .again:
            interval = 10 * 60
            card.stability = max(0.1, card.stability * 0.5)
            card.difficulty = min(10, max(1, card.difficulty + 0.8))
            if previousState == .review {
                card.lapses += 1
            }
            card.state = ReviewState.relearning.rawValue
        case .hard:
            interval = max(15 * 60, Double(max(1, card.scheduledDays)) * 0.75 * 86_400)
            card.stability = max(0.5, card.stability + 0.8)
            card.difficulty = min(10, max(1, card.difficulty + 0.3))
            card.state = ReviewState.review.rawValue
        case .good:
            interval = max(86_400, Double(max(1, card.scheduledDays + 1)) * 86_400)
            card.stability = max(1, card.stability + 1.8)
            card.difficulty = min(10, max(1, card.difficulty))
            card.state = ReviewState.review.rawValue
        case .easy:
            interval = max(4 * 86_400, Double(max(4, card.scheduledDays + 3)) * 86_400)
            card.stability = max(4, card.stability + 3.0)
            card.difficulty = min(10, max(1, card.difficulty - 0.3))
            card.state = ReviewState.review.rawValue
        }

        card.reps += 1
        card.elapsedDays = elapsedDays
        card.scheduledDays = interval / 86_400
        card.dueAt = reviewedAt.addingTimeInterval(interval)
        card.lastReviewAt = reviewedAt
    }
}
