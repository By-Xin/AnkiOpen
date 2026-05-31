import CoreData
import Foundation

@objc(NotebookUnitMO)
final class NotebookUnitMO: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var sortIndex: Int32
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var notebook: NotebookMO
    @NSManaged var flashcards: Set<FlashcardMO>
}

extension NotebookUnitMO {
    static let defaultName = "Default"

    @nonobjc class func fetchRequest() -> NSFetchRequest<NotebookUnitMO> {
        NSFetchRequest<NotebookUnitMO>(entityName: "NotebookUnit")
    }

    var activeCardsCount: Int {
        flashcards.filter { !$0.isArchived }.count
    }

    static func insert(
        name: String,
        notebook: NotebookMO,
        context: NSManagedObjectContext,
        sortIndex: Int32? = nil
    ) -> NotebookUnitMO {
        let now = Date()
        let unit = NotebookUnitMO(context: context)
        unit.id = UUID()
        unit.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        unit.sortIndex = sortIndex ?? nextSortIndex(in: notebook)
        unit.createdAt = now
        unit.updatedAt = now
        unit.notebook = notebook
        return unit
    }

    static func findOrCreateDefault(in notebook: NotebookMO, context: NSManagedObjectContext) -> NotebookUnitMO {
        findOrCreate(named: defaultName, in: notebook, context: context)
    }

    static func findOrCreate(named rawName: String?, in notebook: NotebookMO, context: NSManagedObjectContext) -> NotebookUnitMO {
        let name = normalizedUnitName(rawName)
        if let existing = notebook.units.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }

        let request = fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "notebook == %@ AND name ==[c] %@", notebook, name)
        if let existing = try? context.fetch(request).first {
            return existing
        }

        return insert(name: name, notebook: notebook, context: context)
    }

    static func normalizedUnitName(_ rawName: String?) -> String {
        let trimmed = rawName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return defaultName
        }

        if trimmed.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil {
            return "Unit \(trimmed)"
        }
        return trimmed
    }

    private static func nextSortIndex(in notebook: NotebookMO) -> Int32 {
        let maxIndex = notebook.units.map(\.sortIndex).max() ?? -1
        return maxIndex + 1
    }
}
