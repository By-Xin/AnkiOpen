import CoreData
import Foundation

@objc(FlashcardMO)
final class FlashcardMO: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var front: String
    @NSManaged var back: String
    @NSManaged var frontAudioFileName: String?
    @NSManaged var backAudioFileName: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var isArchived: Bool
    @NSManaged var dueAt: Date
    @NSManaged var stability: Double
    @NSManaged var difficulty: Double
    @NSManaged var elapsedDays: Double
    @NSManaged var scheduledDays: Double
    @NSManaged var learningSteps: Int16
    @NSManaged var reps: Int32
    @NSManaged var lapses: Int32
    @NSManaged var state: Int16
    @NSManaged var lastReviewAt: Date?
    @NSManaged var notebook: NotebookMO
    @NSManaged var unit: NotebookUnitMO?
    @NSManaged var reviewLogs: Set<ReviewLogMO>
}

extension FlashcardMO {
    @nonobjc class func fetchRequest() -> NSFetchRequest<FlashcardMO> {
        NSFetchRequest<FlashcardMO>(entityName: "Flashcard")
    }

    static func insert(
        front: String,
        back: String,
        notebook: NotebookMO,
        context: NSManagedObjectContext,
        frontAudioFileName: String? = nil,
        backAudioFileName: String? = nil
    ) -> FlashcardMO {
        let unit = NotebookUnitMO.findOrCreateDefault(in: notebook, context: context)
        return insert(
            front: front,
            back: back,
            unit: unit,
            context: context,
            frontAudioFileName: frontAudioFileName,
            backAudioFileName: backAudioFileName
        )
    }

    static func insert(
        front: String,
        back: String,
        unit: NotebookUnitMO,
        context: NSManagedObjectContext,
        frontAudioFileName: String? = nil,
        backAudioFileName: String? = nil
    ) -> FlashcardMO {
        let now = Date()
        let card = FlashcardMO(context: context)
        card.id = UUID()
        card.front = front
        card.back = back
        card.frontAudioFileName = frontAudioFileName
        card.backAudioFileName = backAudioFileName
        card.createdAt = now
        card.updatedAt = now
        card.isArchived = false
        card.dueAt = now
        card.stability = 0
        card.difficulty = 0
        card.elapsedDays = 0
        card.scheduledDays = 0
        card.learningSteps = 0
        card.reps = 0
        card.lapses = 0
        card.state = ReviewState.new.rawValue
        card.notebook = unit.notebook
        card.unit = unit
        return card
    }
}
