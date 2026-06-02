import CoreData
import Foundation

struct CZYZDDictionaryEnrichmentSummary: Equatable {
    let checkedCards: Int
    let updatedCards: Int
    let failedCards: Int
    let messages: [String]

    var messageSummary: String? {
        messages.isEmpty ? nil : messages.joined(separator: "\n")
    }
}

protocol CZYZDDictionaryLookingUp {
    func lookup(term: String) async throws -> [CZYZDDictionaryEntry]
}

extension CZYZDDictionaryLookup: CZYZDDictionaryLookingUp {}

@MainActor
final class CZYZDDictionaryEnrichmentService {
    private let lookup: CZYZDDictionaryLookingUp

    init(lookup: CZYZDDictionaryLookingUp = CZYZDDictionaryLookup()) {
        self.lookup = lookup
    }

    func enrichImportedCards(
        lookupTermsByCardID: [UUID: String],
        context: NSManagedObjectContext
    ) async -> CZYZDDictionaryEnrichmentSummary {
        guard !lookupTermsByCardID.isEmpty else {
            return CZYZDDictionaryEnrichmentSummary(checkedCards: 0, updatedCards: 0, failedCards: 0, messages: [])
        }

        var checkedCards = 0
        var updatedCards = 0
        var failedCards = 0
        var messages: [String] = []

        for (cardID, term) in lookupTermsByCardID.sorted(by: { $0.value < $1.value }) {
            checkedCards += 1

            guard let card = fetchCard(id: cardID, context: context) else {
                failedCards += 1
                messages.append("找不到需要查词的导入卡片：\(term)。")
                continue
            }

            guard card.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            do {
                guard let entry = try await lookup.lookup(term: term).first else {
                    failedCards += 1
                    messages.append("潮语词典没有找到 \(term)。")
                    continue
                }

                let back = Self.cardBackText(from: entry)
                guard !back.isEmpty else {
                    failedCards += 1
                    messages.append("潮语词典结果 \(term) 没有可用的潮拼或解释。")
                    continue
                }

                card.back = back
                card.updatedAt = Date()
                updatedCards += 1
            } catch {
                failedCards += 1
                messages.append("潮语词典查询 \(term) 失败：\(error.localizedDescription)")
            }
        }

        return CZYZDDictionaryEnrichmentSummary(
            checkedCards: checkedCards,
            updatedCards: updatedCards,
            failedCards: failedCards,
            messages: messages
        )
    }

    static func cardBackText(from entry: CZYZDDictionaryEntry) -> String {
        return [
            entry.chaopin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? ""
                : "潮拼: \(entry.chaopin.trimmingCharacters(in: .whitespacesAndNewlines))",
            entry.definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? ""
                : "解释: \(entry.definition.trimmingCharacters(in: .whitespacesAndNewlines))"
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    private func fetchCard(id: UUID, context: NSManagedObjectContext) -> FlashcardMO? {
        let request = FlashcardMO.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }
}
