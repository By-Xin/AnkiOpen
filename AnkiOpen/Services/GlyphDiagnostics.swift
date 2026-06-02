import Foundation

struct GlyphDiagnostics {
    struct Finding: Hashable {
        let scalar: UnicodeScalar
        let category: Category

        var codePoint: String {
            "U+\(String(scalar.value, radix: 16).uppercased())"
        }

        var hasSuggestion: Bool {
            GlyphReplacementSuggestionStore.suggestion(for: scalar) != nil
        }

        var suggestionStatusTitle: String {
            hasSuggestion ? "已保存 DeepSeek 建议" : "需要 DeepSeek 建议"
        }
    }

    enum Category: String {
        case cjkExtensionB = "CJK Extension B"
        case cjkExtensionCToI = "CJK Extension C-I"
        case privateUse = "Private Use"
        case ideographicDescription = "IDS"
        case variationSelector = "Variation Selector"
    }

    static func findings(in text: String) -> [Finding] {
        var seen = Set<UInt32>()
        return text.unicodeScalars.compactMap { scalar in
            guard seen.insert(scalar.value).inserted,
                  let category = category(for: scalar.value) else {
                return nil
            }
            return Finding(scalar: scalar, category: category)
        }
    }

    static func containsRiskyGlyphs(_ text: String) -> Bool {
        !findings(in: text).isEmpty
    }

    static func warningSummary(for text: String, limit: Int = 6) -> String? {
        let findings = findings(in: text)
        guard !findings.isEmpty else {
            return nil
        }

        let visible = findings.prefix(limit).map { finding in
            "\(finding.codePoint) (\(finding.category.rawValue), \(finding.suggestionStatusTitle))"
        }
        let suffix = findings.count > limit ? " +\(findings.count - limit) 个" : ""
        return visible.joined(separator: ", ") + suffix
    }

    static func importWarnings(front: String, back: String, sourceLine: Int) -> [String] {
        [
            importWarning(side: "正面", text: front, sourceLine: sourceLine),
            importWarning(side: "背面", text: back, sourceLine: sourceLine)
        ].compactMap { $0 }
    }

    private static func importWarning(side: String, text: String, sourceLine: Int) -> String? {
        guard let summary = warningSummary(for: text) else {
            return nil
        }
        return "第 \(sourceLine) 行：\(side)含有生僻字：\(summary)"
    }

    private static func category(for value: UInt32) -> Category? {
        switch value {
        case 0x20000...0x2A6DF:
            return .cjkExtensionB
        case 0x2A700...0x2EBEF, 0x30000...0x323AF:
            return .cjkExtensionCToI
        case 0xE000...0xF8FF, 0xF0000...0xFFFFD, 0x100000...0x10FFFD:
            return .privateUse
        case 0x2FF0...0x2FFF:
            return .ideographicDescription
        case 0xFE00...0xFE0F, 0xE0100...0xE01EF:
            return .variationSelector
        default:
            return nil
        }
    }
}

struct GlyphInventoryItem: Identifiable, Equatable {
    let finding: GlyphDiagnostics.Finding
    let occurrences: Int
    let cards: [FlashcardMO]

    var id: UInt32 {
        finding.scalar.value
    }
}

enum GlyphInventory {
    static func items(for cards: [FlashcardMO]) -> [GlyphInventoryItem] {
        var occurrencesByScalar: [UInt32: Int] = [:]
        var findingByScalar: [UInt32: GlyphDiagnostics.Finding] = [:]
        var cardsByScalar: [UInt32: [FlashcardMO]] = [:]
        var cardIDsByScalar: [UInt32: Set<UUID>] = [:]

        for card in cards {
            let text = card.front + card.back
            let findings = GlyphDiagnostics.findings(in: text)
            guard !findings.isEmpty else {
                continue
            }

            for scalar in text.unicodeScalars {
                guard let finding = findings.first(where: { $0.scalar.value == scalar.value }) else {
                    continue
                }

                occurrencesByScalar[scalar.value, default: 0] += 1
                findingByScalar[scalar.value] = finding

                if cardIDsByScalar[scalar.value, default: []].insert(card.id).inserted {
                    cardsByScalar[scalar.value, default: []].append(card)
                }
            }
        }

        return findingByScalar.keys.sorted().compactMap { value in
            guard let finding = findingByScalar[value] else {
                return nil
            }
            return GlyphInventoryItem(
                finding: finding,
                occurrences: occurrencesByScalar[value, default: 0],
                cards: cardsByScalar[value, default: []]
            )
        }
    }
}
