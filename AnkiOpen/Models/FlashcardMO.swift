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
    @NSManaged var reports: Set<CardReportMO>
    @NSManaged var correctionLogs: Set<CardCorrectionLogMO>
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

    func archive(at date: Date = Date()) {
        isArchived = true
        updatedAt = date
    }

    func restore(at date: Date = Date()) {
        isArchived = false
        updatedAt = date
    }

    var isMissingAudio: Bool {
        !isArchived && (frontAudioFileName == nil || backAudioFileName == nil)
    }

    var missingAudioTitle: String {
        switch (frontAudioFileName == nil, backAudioFileName == nil) {
        case (true, true):
            return "正反两面缺音频"
        case (true, false):
            return "正面缺音频"
        case (false, true):
            return "背面缺音频"
        case (false, false):
            return "音频完整"
        }
    }

    var locationTitle: String {
        if let unit {
            return "\(notebook.name) / \(unit.name)"
        }
        return notebook.name
    }
}

enum MissingAudioScope: String, CaseIterable, Identifiable {
    case all
    case front
    case back
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .front:
            return "缺正面"
        case .back:
            return "缺背面"
        case .both:
            return "两面都缺"
        }
    }
}

struct MissingAudioCardFilter: Equatable {
    var scope: MissingAudioScope = .all
    var searchText: String = ""

    func matches(_ card: FlashcardMO) -> Bool {
        guard card.isMissingAudio else {
            return false
        }

        let matchesScope: Bool
        switch scope {
        case .all:
            matchesScope = true
        case .front:
            matchesScope = card.frontAudioFileName == nil
        case .back:
            matchesScope = card.backAudioFileName == nil
        case .both:
            matchesScope = card.frontAudioFileName == nil && card.backAudioFileName == nil
        }

        guard matchesScope else {
            return false
        }

        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            return true
        }

        return card.front.localizedCaseInsensitiveContains(term)
            || card.back.localizedCaseInsensitiveContains(term)
            || card.notebook.name.localizedCaseInsensitiveContains(term)
            || (card.unit?.name.localizedCaseInsensitiveContains(term) ?? false)
            || card.missingAudioTitle.localizedCaseInsensitiveContains(term)
    }
}
