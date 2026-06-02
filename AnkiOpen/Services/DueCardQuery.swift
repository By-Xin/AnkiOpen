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
            return "到期"
        case .all:
            return "全部"
        case .notDue:
            return "强制"
        }
    }

    var emptyTitle: String {
        switch self {
        case .due:
            return "今天没有到期卡片"
        case .all:
            return "没有卡片"
        case .notDue:
            return "没有可强制学习的卡片"
        }
    }

    var emptyMessage: String {
        switch self {
        case .due:
            return "当前已经复习完成。"
        case .all:
            return "新建或导入卡片后即可开始学习。"
        case .notDue:
            return "当前选择范围里没有尚未到期的卡片。"
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
