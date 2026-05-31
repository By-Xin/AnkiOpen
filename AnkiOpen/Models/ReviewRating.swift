import Foundation

enum ReviewRating: Int16, CaseIterable, Identifiable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    var id: Int16 { rawValue }

    var title: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }
}

enum ReviewState: Int16 {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}
