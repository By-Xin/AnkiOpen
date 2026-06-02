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
    static let defaultName = "默认单元"

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

        if let localizedName = localizedLegacyName(for: trimmed) {
            return localizedName
        }

        if trimmed.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil {
            return "单元 \(trimmed)"
        }
        return trimmed
    }

    static func migrateLegacyEnglishNames(context: NSManagedObjectContext) throws {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NotebookUnitMO.sortIndex, ascending: true)]
        let units = try context.fetch(request)
        let now = Date()

        for unit in units {
            guard let localizedName = localizedLegacyName(for: unit.name) else {
                continue
            }

            if let target = unit.notebook.units.first(where: {
                $0 !== unit && $0.name.caseInsensitiveCompare(localizedName) == .orderedSame
            }) {
                for card in unit.flashcards {
                    card.unit = target
                    card.updatedAt = now
                }
                target.updatedAt = now
                context.delete(unit)
            } else {
                unit.name = localizedName
                unit.updatedAt = now
            }
        }

        if context.hasChanges {
            try context.save()
        }
    }

    private static func localizedLegacyName(for rawName: String) -> String? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.caseInsensitiveCompare("Default") == .orderedSame {
            return defaultName
        }

        let lowercased = trimmed.lowercased()
        guard lowercased.hasPrefix("unit ") else {
            return nil
        }

        let number = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !number.isEmpty,
              number.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil else {
            return nil
        }
        return "单元 \(number)"
    }

    private static func nextSortIndex(in notebook: NotebookMO) -> Int32 {
        let maxIndex = notebook.units.map(\.sortIndex).max() ?? -1
        return maxIndex + 1
    }
}
