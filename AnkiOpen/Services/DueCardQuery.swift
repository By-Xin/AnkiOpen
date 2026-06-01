import CoreData
import Foundation

enum StudyMode: String, CaseIterable, Identifiable {
    case due
    case all
    case notDue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .due:
            return "Due"
        case .all:
            return "All"
        case .notDue:
            return "Forced"
        }
    }

    var emptyTitle: String {
        switch self {
        case .due:
            return "No Due Cards"
        case .all:
            return "No Cards"
        case .notDue:
            return "No Forced Cards"
        }
    }

    var emptyMessage: String {
        switch self {
        case .due:
            return "You are caught up for now."
        case .all:
            return "Add or import cards to start studying."
        case .notDue:
            return "There are no not-yet-due cards in this selection."
        }
    }
}

enum DueCardQuery {
    static func fetchRequest(for notebook: NotebookMO?, at date: Date = Date()) -> NSFetchRequest<FlashcardMO> {
        fetchRequest(for: notebook, mode: .due, at: date)
    }

    static func fetchRequest(
        for notebook: NotebookMO?,
        mode: StudyMode,
        at date: Date = Date()
    ) -> NSFetchRequest<FlashcardMO> {
        fetchRequest(for: notebook, unit: nil, mode: mode, at: date)
    }

    static func fetchRequest(
        for notebook: NotebookMO?,
        unit: NotebookUnitMO?,
        mode: StudyMode,
        at date: Date = Date()
    ) -> NSFetchRequest<FlashcardMO> {
        let request = FlashcardMO.fetchRequest()

        var predicates: [NSPredicate] = [
            NSPredicate(format: "isArchived == NO")
        ]

        if let unit {
            predicates.append(NSPredicate(format: "unit == %@", unit))
        } else if let notebook {
            predicates.append(NSPredicate(format: "notebook == %@", notebook))
        }

        switch mode {
        case .due:
            predicates.append(NSPredicate(format: "dueAt <= %@", date as NSDate))
        case .all:
            break
        case .notDue:
            predicates.append(NSPredicate(format: "dueAt > %@", date as NSDate))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = sortDescriptors(for: mode)
        return request
    }

    static func forNotebook(_ notebook: NotebookMO?, at date: Date = Date(), context: NSManagedObjectContext) throws -> [FlashcardMO] {
        try context.fetch(fetchRequest(for: notebook, at: date))
    }

    static func forNotebook(
        _ notebook: NotebookMO?,
        mode: StudyMode,
        at date: Date = Date(),
        context: NSManagedObjectContext
    ) throws -> [FlashcardMO] {
        try context.fetch(fetchRequest(for: notebook, mode: mode, at: date))
    }

    static func forNotebook(
        _ notebook: NotebookMO?,
        unit: NotebookUnitMO?,
        mode: StudyMode,
        at date: Date = Date(),
        context: NSManagedObjectContext
    ) throws -> [FlashcardMO] {
        try context.fetch(fetchRequest(for: notebook, unit: unit, mode: mode, at: date))
    }

    private static func sortDescriptors(for mode: StudyMode) -> [NSSortDescriptor] {
        switch mode {
        case .due, .notDue:
            return [
                NSSortDescriptor(keyPath: \FlashcardMO.dueAt, ascending: true),
                NSSortDescriptor(keyPath: \FlashcardMO.createdAt, ascending: true)
            ]
        case .all:
            return [
                NSSortDescriptor(keyPath: \FlashcardMO.createdAt, ascending: true),
                NSSortDescriptor(keyPath: \FlashcardMO.dueAt, ascending: true)
            ]
        }
    }
}

enum StudyQueueOrder {
    static func apply<T, R: RandomNumberGenerator>(
        to cards: [T],
        shuffle: Bool,
        using generator: inout R
    ) -> [T] {
        guard shuffle else {
            return cards
        }

        return cards.shuffled(using: &generator)
    }

    static func apply<T>(to cards: [T], shuffle: Bool) -> [T] {
        guard shuffle else {
            return cards
        }

        return cards.shuffled()
    }
}
