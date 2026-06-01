import Foundation

struct FSRS6ReviewOutput {
    let dueAt: Date
    let stability: Double
    let difficulty: Double
    let elapsedDays: Double
    let scheduledDays: Double
    let reps: Int32
    let lapses: Int32
    let state: ReviewState
    let lastReviewAt: Date
}

struct FSRS6Scheduler {
    struct Parameters {
        var requestRetention: Double = 0.90
        var maximumInterval: Double = 36_500
        var enableShortTerm: Bool = true

        // FSRS-6 default weights from open-spaced-repetition/awesome-fsrs.
        var weights: [Double] = [
            0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194,
            0.001, 1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629,
            1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542
        ]
    }

    private struct MemoryState {
        var dueAt: Date
        var stability: Double
        var difficulty: Double
        var elapsedDays: Double
        var scheduledDays: Double
        var reps: Int32
        var lapses: Int32
        var state: ReviewState
        var lastReviewAt: Date?
    }

    private let parameters: Parameters

    init(parameters: Parameters = Parameters()) {
        self.parameters = parameters
    }

    func review(card: FlashcardMO, rating: ReviewRating, reviewedAt: Date) -> FSRS6ReviewOutput {
        let previous = MemoryState(
            dueAt: card.dueAt,
            stability: card.stability,
            difficulty: card.difficulty,
            elapsedDays: card.elapsedDays,
            scheduledDays: card.scheduledDays,
            reps: card.reps,
            lapses: card.lapses,
            state: ReviewState(rawValue: card.state) ?? .new,
            lastReviewAt: card.lastReviewAt
        )
        let elapsedDays = elapsedDays(reviewedAt: reviewedAt, previousReviewAt: previous.lastReviewAt)

        let next: MemoryState
        if previous.state == .new {
            next = newState(from: previous, rating: rating, reviewedAt: reviewedAt)
        } else if parameters.enableShortTerm && (previous.state == .learning || previous.state == .relearning) {
            next = learningState(from: previous, rating: rating, reviewedAt: reviewedAt, elapsedDays: elapsedDays)
        } else {
            next = reviewState(from: previous, rating: rating, reviewedAt: reviewedAt, elapsedDays: elapsedDays)
        }

        return FSRS6ReviewOutput(
            dueAt: next.dueAt,
            stability: next.stability,
            difficulty: next.difficulty,
            elapsedDays: elapsedDays,
            scheduledDays: next.scheduledDays,
            reps: previous.reps + 1,
            lapses: next.lapses,
            state: next.state,
            lastReviewAt: reviewedAt
        )
    }

    private func newState(from previous: MemoryState, rating: ReviewRating, reviewedAt: Date) -> MemoryState {
        var next = previous
        next.difficulty = initialDifficulty(for: rating)
        next.stability = initialStability(for: rating)

        switch rating {
        case .again:
            next.scheduledDays = 0
            next.dueAt = reviewedAt.addingTimeInterval(60)
            next.state = .learning
        case .hard:
            next.scheduledDays = 0
            next.dueAt = reviewedAt.addingTimeInterval(5 * 60)
            next.state = .learning
        case .good:
            next.scheduledDays = 0
            next.dueAt = reviewedAt.addingTimeInterval(10 * 60)
            next.state = .learning
        case .easy:
            let interval = nextInterval(stability: next.stability, elapsedDays: 0)
            next.scheduledDays = Double(interval)
            next.dueAt = dueDate(reviewedAt: reviewedAt, scheduledDays: next.scheduledDays)
            next.state = .review
        }

        return next
    }

    private func learningState(
        from previous: MemoryState,
        rating: ReviewRating,
        reviewedAt: Date,
        elapsedDays: Double
    ) -> MemoryState {
        var next = previous
        next.difficulty = nextDifficulty(previous.difficulty, rating: rating)
        next.stability = nextShortTermStability(previous.stability, rating: rating)

        switch rating {
        case .again:
            next.scheduledDays = 0
            next.dueAt = reviewedAt.addingTimeInterval(5 * 60)
            next.state = previous.state
        case .hard:
            next.scheduledDays = 0
            next.dueAt = reviewedAt.addingTimeInterval(10 * 60)
            next.state = previous.state
        case .good:
            let interval = nextInterval(stability: next.stability, elapsedDays: elapsedDays)
            next.scheduledDays = Double(interval)
            next.dueAt = dueDate(reviewedAt: reviewedAt, scheduledDays: next.scheduledDays)
            next.state = .review
        case .easy:
            let goodStability = nextShortTermStability(previous.stability, rating: .good)
            let goodInterval = nextInterval(stability: goodStability, elapsedDays: elapsedDays)
            let interval = max(nextInterval(stability: next.stability, elapsedDays: elapsedDays), goodInterval + 1)
            next.scheduledDays = Double(interval)
            next.dueAt = dueDate(reviewedAt: reviewedAt, scheduledDays: next.scheduledDays)
            next.state = .review
        }

        return next
    }

    private func reviewState(
        from previous: MemoryState,
        rating: ReviewRating,
        reviewedAt: Date,
        elapsedDays: Double
    ) -> MemoryState {
        let stability = max(previous.stability, 0.01)
        let difficulty = clamp(previous.difficulty == 0 ? initialDifficulty(for: .good) : previous.difficulty, 1, 10)
        let retrievability = forgettingCurve(elapsedDays: elapsedDays, stability: stability)

        var next = previous
        next.difficulty = nextDifficulty(difficulty, rating: rating)

        switch rating {
        case .again:
            next.stability = nextForgetStability(difficulty: difficulty, stability: stability, retrievability: retrievability)
            next.scheduledDays = 0
            next.dueAt = reviewedAt.addingTimeInterval(5 * 60)
            next.state = .relearning
            if previous.state == .review {
                next.lapses += 1
            }
        case .hard:
            next.stability = nextRecallStability(
                difficulty: difficulty,
                stability: stability,
                retrievability: retrievability,
                rating: .hard
            )
            let goodStability = nextRecallStability(
                difficulty: difficulty,
                stability: stability,
                retrievability: retrievability,
                rating: .good
            )
            let hardInterval = nextInterval(stability: next.stability, elapsedDays: elapsedDays)
            let goodInterval = nextInterval(stability: goodStability, elapsedDays: elapsedDays)
            next.scheduledDays = Double(min(hardInterval, goodInterval))
            next.dueAt = dueDate(reviewedAt: reviewedAt, scheduledDays: next.scheduledDays)
            next.state = .review
        case .good:
            let hardStability = nextRecallStability(
                difficulty: difficulty,
                stability: stability,
                retrievability: retrievability,
                rating: .hard
            )
            next.stability = nextRecallStability(
                difficulty: difficulty,
                stability: stability,
                retrievability: retrievability,
                rating: .good
            )
            let hardInterval = nextInterval(stability: hardStability, elapsedDays: elapsedDays)
            let goodInterval = nextInterval(stability: next.stability, elapsedDays: elapsedDays)
            next.scheduledDays = Double(max(goodInterval, hardInterval + 1))
            next.dueAt = dueDate(reviewedAt: reviewedAt, scheduledDays: next.scheduledDays)
            next.state = .review
        case .easy:
            let goodStability = nextRecallStability(
                difficulty: difficulty,
                stability: stability,
                retrievability: retrievability,
                rating: .good
            )
            next.stability = nextRecallStability(
                difficulty: difficulty,
                stability: stability,
                retrievability: retrievability,
                rating: .easy
            )
            let goodInterval = nextInterval(stability: goodStability, elapsedDays: elapsedDays)
            let easyInterval = nextInterval(stability: next.stability, elapsedDays: elapsedDays)
            next.scheduledDays = Double(max(easyInterval, goodInterval + 1))
            next.dueAt = dueDate(reviewedAt: reviewedAt, scheduledDays: next.scheduledDays)
            next.state = .review
        }

        return next
    }

    private func initialStability(for rating: ReviewRating) -> Double {
        max(parameters.weights[Int(rating.rawValue) - 1], 0.1)
    }

    private func initialDifficulty(for rating: ReviewRating) -> Double {
        clamp(
            parameters.weights[4] - exp(parameters.weights[5] * (Double(rating.rawValue) - 1)) + 1,
            1,
            10
        )
    }

    private func nextDifficulty(_ difficulty: Double, rating: ReviewRating) -> Double {
        let delta = -parameters.weights[6] * (Double(rating.rawValue) - 3)
        let damped = difficulty + delta * (10 - difficulty) / 9
        let reverted = parameters.weights[7] * initialDifficulty(for: .easy) + (1 - parameters.weights[7]) * damped
        return clamp(reverted, 1, 10)
    }

    private func nextRecallStability(
        difficulty: Double,
        stability: Double,
        retrievability: Double,
        rating: ReviewRating
    ) -> Double {
        let hardPenalty = rating == .hard ? parameters.weights[15] : 1
        let easyBonus = rating == .easy ? parameters.weights[16] : 1
        return clamp(
            stability * (
                1 + exp(parameters.weights[8]) * (11 - difficulty) * pow(stability, -parameters.weights[9])
                * (exp((1 - retrievability) * parameters.weights[10]) - 1) * hardPenalty * easyBonus
            ),
            0.01,
            parameters.maximumInterval
        )
    }

    private func nextForgetStability(difficulty: Double, stability: Double, retrievability: Double) -> Double {
        clamp(
            parameters.weights[11] * pow(difficulty, -parameters.weights[12])
            * (pow(stability + 1, parameters.weights[13]) - 1)
            * exp(parameters.weights[14] * (1 - retrievability)),
            0.01,
            parameters.maximumInterval
        )
    }

    private func nextShortTermStability(_ stability: Double, rating: ReviewRating) -> Double {
        let increase = exp(parameters.weights[17] * (Double(rating.rawValue) - 3 + parameters.weights[18]))
        return clamp(
            stability * increase * pow(max(stability, 0.01), -parameters.weights[19]),
            0.01,
            parameters.maximumInterval
        )
    }

    private func forgettingCurve(elapsedDays: Double, stability: Double) -> Double {
        pow(1 + forgettingFactor * elapsedDays / stability, -parameters.weights[20])
    }

    private var forgettingFactor: Double {
        pow(0.9, -1 / parameters.weights[20]) - 1
    }

    private func nextInterval(stability: Double, elapsedDays: Double) -> Int {
        let intervalModifier = (pow(parameters.requestRetention, -1 / parameters.weights[20]) - 1) / forgettingFactor
        let interval = min(max(1, round(stability * intervalModifier)), parameters.maximumInterval)
        return Int(interval)
    }

    private func dueDate(reviewedAt: Date, scheduledDays: Double) -> Date {
        reviewedAt.addingTimeInterval(scheduledDays * 86_400)
    }

    private func elapsedDays(reviewedAt: Date, previousReviewAt: Date?) -> Double {
        guard let previousReviewAt else { return 0 }
        return max(0, floor(reviewedAt.timeIntervalSince(previousReviewAt) / 86_400))
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
