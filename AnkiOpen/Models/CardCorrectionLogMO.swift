import CoreData
import Foundation

@objc(CardCorrectionLogMO)
final class CardCorrectionLogMO: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var createdAt: Date
    @NSManaged var previousFront: String
    @NSManaged var previousBack: String
    @NSManaged var previousFrontAudioFileName: String?
    @NSManaged var previousBackAudioFileName: String?
    @NSManaged var nextFront: String
    @NSManaged var nextBack: String
    @NSManaged var nextFrontAudioFileName: String?
    @NSManaged var nextBackAudioFileName: String?
    @NSManaged var card: FlashcardMO
    @NSManaged var report: CardReportMO?
}

extension CardCorrectionLogMO {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CardCorrectionLogMO> {
        NSFetchRequest<CardCorrectionLogMO>(entityName: "CardCorrectionLog")
    }

    static func insert(
        report: CardReportMO?,
        card: FlashcardMO,
        before: CardCorrectionSnapshot,
        after: CardCorrectionSnapshot,
        context: NSManagedObjectContext,
        createdAt: Date = Date()
    ) -> CardCorrectionLogMO {
        let log = CardCorrectionLogMO(context: context)
        log.id = UUID()
        log.createdAt = createdAt
        log.previousFront = before.front
        log.previousBack = before.back
        log.previousFrontAudioFileName = before.frontAudioFileName
        log.previousBackAudioFileName = before.backAudioFileName
        log.nextFront = after.front
        log.nextBack = after.back
        log.nextFrontAudioFileName = after.frontAudioFileName
        log.nextBackAudioFileName = after.backAudioFileName
        log.card = card
        log.report = report
        return log
    }

    var changedFieldTitles: [String] {
        CardCorrectionSnapshot(
            front: previousFront,
            back: previousBack,
            frontAudioFileName: previousFrontAudioFileName,
            backAudioFileName: previousBackAudioFileName
        )
        .changedFieldTitles(
            comparedTo: CardCorrectionSnapshot(
                front: nextFront,
                back: nextBack,
                frontAudioFileName: nextFrontAudioFileName,
                backAudioFileName: nextBackAudioFileName
            )
        )
    }
}

struct CardCorrectionSnapshot: Equatable {
    let front: String
    let back: String
    let frontAudioFileName: String?
    let backAudioFileName: String?

    init(card: FlashcardMO) {
        self.front = card.front
        self.back = card.back
        self.frontAudioFileName = card.frontAudioFileName
        self.backAudioFileName = card.backAudioFileName
    }

    init(
        front: String,
        back: String,
        frontAudioFileName: String?,
        backAudioFileName: String?
    ) {
        self.front = front
        self.back = back
        self.frontAudioFileName = frontAudioFileName
        self.backAudioFileName = backAudioFileName
    }

    func changedFieldTitles(comparedTo other: CardCorrectionSnapshot) -> [String] {
        var titles: [String] = []
        if front != other.front {
            titles.append("正面")
        }
        if back != other.back {
            titles.append("背面")
        }
        if frontAudioFileName != other.frontAudioFileName {
            titles.append("正面音频")
        }
        if backAudioFileName != other.backAudioFileName {
            titles.append("背面音频")
        }
        return titles
    }
}
