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

    var hasBrokenAudioReference: Bool {
        !isArchived && (
            isBrokenAudioReference(frontAudioFileName) || isBrokenAudioReference(backAudioFileName)
        )
    }

    var needsAudioAttention: Bool {
        isMissingAudio || hasBrokenAudioReference
    }

    var missingAudioTitle: String {
        switch (frontAudioStatus, backAudioStatus) {
        case (.missing, .missing):
            return "正反两面缺音频"
        case (.missing, _):
            return "正面缺音频"
        case (_, .missing):
            return "背面缺音频"
        case (.broken, .broken):
            return "正反两面音频文件缺失"
        case (.broken, _):
            return "正面音频文件缺失"
        case (_, .broken):
            return "背面音频文件缺失"
        case (.available, .available):
            return "音频完整"
        }
    }

    var isFrontAudioMissingOrBroken: Bool {
        frontAudioStatus != .available
    }

    var isBackAudioMissingOrBroken: Bool {
        backAudioStatus != .available
    }

    var isBothSidesMissingOrBroken: Bool {
        isFrontAudioMissingOrBroken && isBackAudioMissingOrBroken
    }

    func clearBrokenAudioReferences() {
        if isBrokenAudioReference(frontAudioFileName) {
            frontAudioFileName = nil
        }
        if isBrokenAudioReference(backAudioFileName) {
            backAudioFileName = nil
        }
    }

    var locationTitle: String {
        if let unit {
            return "\(notebook.name) / \(unit.name)"
        }
        return notebook.name
    }

    private var frontAudioStatus: AudioReferenceStatus {
        audioReferenceStatus(for: frontAudioFileName)
    }

    private var backAudioStatus: AudioReferenceStatus {
        audioReferenceStatus(for: backAudioFileName)
    }

    private func audioReferenceStatus(for storedFileName: String?) -> AudioReferenceStatus {
        guard AudioFileStore.cleanedStoredFileName(storedFileName) != nil else {
            return .missing
        }
        return AudioFileStore.storedAudioExists(storedFileName) ? .available : .broken
    }

    private func isBrokenAudioReference(_ storedFileName: String?) -> Bool {
        guard AudioFileStore.cleanedStoredFileName(storedFileName) != nil else {
            return false
        }
        return !AudioFileStore.storedAudioExists(storedFileName)
    }
}

private enum AudioReferenceStatus {
    case missing
    case broken
    case available
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
        guard card.needsAudioAttention else {
            return false
        }

        let matchesScope: Bool
        switch scope {
        case .all:
            matchesScope = true
        case .front:
            matchesScope = card.isFrontAudioMissingOrBroken
        case .back:
            matchesScope = card.isBackAudioMissingOrBroken
        case .both:
            matchesScope = card.isBothSidesMissingOrBroken
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

struct AudioIntegritySummary: Equatable {
    let attentionCards: Int
    let missingFront: Int
    let missingBack: Int
    let brokenReferences: Int

    init(cards: [FlashcardMO]) {
        let active = cards.filter { !$0.isArchived }
        attentionCards = active.filter(\.needsAudioAttention).count
        missingFront = active.filter(\.isFrontAudioMissingOrBroken).count
        missingBack = active.filter(\.isBackAudioMissingOrBroken).count
        brokenReferences = active.reduce(0) { count, card in
            count
                + Self.brokenReferenceCount(for: card.frontAudioFileName)
                + Self.brokenReferenceCount(for: card.backAudioFileName)
        }
    }

    private static func brokenReferenceCount(for storedFileName: String?) -> Int {
        guard AudioFileStore.cleanedStoredFileName(storedFileName) != nil else {
            return 0
        }
        return AudioFileStore.storedAudioExists(storedFileName) ? 0 : 1
    }
}
