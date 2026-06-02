import CoreData
import Foundation

struct CZYZDAudioAttachmentSummary: Equatable {
    let checkedCards: Int
    let matchedCards: Int
    let failedCards: Int
    let messages: [String]

    var messageSummary: String? {
        messages.isEmpty ? nil : messages.joined(separator: "\n")
    }
}

struct CZYZDAudioDownload {
    let data: Data
    let suggestedFileName: String
}

protocol CZYZDAudioResolving {
    func downloadAudio(for term: String) async throws -> CZYZDAudioDownload?
}

enum CZYZDAudioResolverError: LocalizedError {
    case invalidSearchURL
    case invalidResponse
    case invalidHTML
    case invalidAudioResponse

    var errorDescription: String? {
        switch self {
        case .invalidSearchURL:
            return "Could not build the CZYZD search URL."
        case .invalidResponse:
            return "CZYZD search returned an invalid response."
        case .invalidHTML:
            return "CZYZD search returned unreadable HTML."
        case .invalidAudioResponse:
            return "CZYZD audio download returned an invalid response."
        }
    }
}

final class CZYZDAudioResolver: CZYZDAudioResolving {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func downloadAudio(for term: String) async throws -> CZYZDAudioDownload? {
        guard let audioURL = try await resolveAudioURL(for: term) else {
            return nil
        }

        var request = URLRequest(url: audioURL)
        request.timeoutInterval = 20
        request.setValue("http://www.czyzd.com/", forHTTPHeaderField: "Referer")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              !data.isEmpty else {
            throw CZYZDAudioResolverError.invalidAudioResponse
        }

        return CZYZDAudioDownload(
            data: data,
            suggestedFileName: "\(Self.safeFileStem(for: term)).\(audioURL.pathExtension.isEmpty ? "mp3" : audioURL.pathExtension)"
        )
    }

    func resolveAudioURL(for term: String) async throws -> URL? {
        guard let url = Self.searchURL(for: term) else {
            throw CZYZDAudioResolverError.invalidSearchURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("http://www.czyzd.com/", forHTTPHeaderField: "Referer")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw CZYZDAudioResolverError.invalidResponse
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw CZYZDAudioResolverError.invalidHTML
        }

        return Self.bestAudioURL(in: html, matching: term)
    }

    static func searchURL(for term: String) -> URL? {
        let cleanTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTerm.isEmpty else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "http"
        components.host = "www.czyzd.com"
        components.path = "/search"
        components.queryItems = [URLQueryItem(name: "keyword", value: cleanTerm)]
        return components.url
    }

    static func firstAudioURL(in html: String) -> URL? {
        firstCZYZDAudioURL(in: html)
    }

    static func bestAudioURL(in html: String, matching term: String) -> URL? {
        let normalizedTerm = normalizedLookupText(term)
        guard !normalizedTerm.isEmpty else {
            return nil
        }

        let entries = dictionaryEntries(in: html)
        if let exactEntry = entries.first(where: { normalizedLookupText($0.title) == normalizedTerm }) {
            return firstCZYZDAudioURL(in: exactEntry.html)
        }

        if normalizedTerm.count == 1 {
            return entries.lazy.compactMap { firstCZYZDAudioURL(in: $0.html) }.first ?? firstCZYZDAudioURL(in: html)
        }

        return nil
    }

    private static func safeFileStem(for term: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let clean = term
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
        let stem = String(clean).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return stem.isEmpty ? "czyzd-audio" : stem
    }

    private static func dictionaryEntries(in html: String) -> [(title: String, html: String)] {
        let pattern = #"(?s)<dl>\s*<dt>.*?<p>(.*?)</p>.*?</dl>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard let blockRange = Range(match.range(at: 0), in: html),
                  let titleRange = Range(match.range(at: 1), in: html) else {
                return nil
            }

            return (
                title: decodedHTMLText(String(html[titleRange])),
                html: String(html[blockRange])
            )
        }
    }

    private static func firstCZYZDAudioURL(in html: String) -> URL? {
        let pattern = #"https://api\.czyzd\.com/sound/czh/[^"'<>\s]+?\.mp3"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let matchRange = Range(match.range, in: html) else {
            return nil
        }

        let value = String(html[matchRange])
            .replacingOccurrences(of: "&amp;", with: "&")
        return URL(string: value)
    }

    private static func normalizedLookupText(_ value: String) -> String {
        decodedHTMLText(value)
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodedHTMLText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    private static let userAgent = "AnkiOpen/0.1 CZYZD Audio Import"
}

@MainActor
final class CZYZDAudioAttachmentService {
    private let resolver: CZYZDAudioResolving

    init(resolver: CZYZDAudioResolving = CZYZDAudioResolver()) {
        self.resolver = resolver
    }

    func attachMissingAudio(
        toImportedCardIDs cardIDs: [UUID],
        context: NSManagedObjectContext
    ) async -> CZYZDAudioAttachmentSummary {
        guard !cardIDs.isEmpty else {
            return CZYZDAudioAttachmentSummary(checkedCards: 0, matchedCards: 0, failedCards: 0, messages: [])
        }

        let request = FlashcardMO.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlashcardMO.createdAt, ascending: true)]
        request.predicate = NSPredicate(
            format: "id IN %@ AND (frontAudioFileName == nil OR backAudioFileName == nil) AND isArchived == NO",
            cardIDs
        )
        return await attachMissingAudio(matching: request, failedFetchCount: cardIDs.count, context: context)
    }

    func attachMissingAudio(
        in notebook: NotebookMO,
        unit: NotebookUnitMO? = nil,
        context: NSManagedObjectContext
    ) async -> CZYZDAudioAttachmentSummary {
        let request = FlashcardMO.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FlashcardMO.createdAt, ascending: true)]

        if let unit {
            request.predicate = NSPredicate(
                format: "notebook == %@ AND unit == %@ AND (frontAudioFileName == nil OR backAudioFileName == nil) AND isArchived == NO",
                notebook,
                unit
            )
        } else {
            request.predicate = NSPredicate(
                format: "notebook == %@ AND (frontAudioFileName == nil OR backAudioFileName == nil) AND isArchived == NO",
                notebook
            )
        }

        return await attachMissingAudio(matching: request, failedFetchCount: 0, context: context)
    }

    private func attachMissingAudio(
        matching request: NSFetchRequest<FlashcardMO>,
        failedFetchCount: Int,
        context: NSManagedObjectContext
    ) async -> CZYZDAudioAttachmentSummary {
        let cards: [FlashcardMO]
        do {
            cards = try context.fetch(request)
        } catch {
            return CZYZDAudioAttachmentSummary(
                checkedCards: 0,
                matchedCards: 0,
                failedCards: failedFetchCount,
                messages: ["Could not load imported cards for CZYZD matching."]
            )
        }

        var matched = 0
        var failed = 0
        var messages: [String] = []

        for card in cards {
            do {
                if attachExistingAudioIfPossible(to: card) {
                    matched += 1
                    continue
                }

                guard let download = try await resolver.downloadAudio(for: card.front) else {
                    continue
                }

                let storedFileName = try AudioFileStore.storeDownloadedAudio(
                    data: download.data,
                    suggestedFileName: download.suggestedFileName
                )
                card.frontAudioFileName = storedFileName
                if card.backAudioFileName == nil {
                    card.backAudioFileName = storedFileName
                }
                card.updatedAt = Date()
                matched += 1
            } catch {
                failed += 1
                if messages.count < 8 {
                    messages.append("\(card.front): \(error.localizedDescription)")
                }
            }
        }

        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            messages.append("Could not save matched CZYZD audio.")
        }

        return CZYZDAudioAttachmentSummary(
            checkedCards: cards.count,
            matchedCards: matched,
            failedCards: failed,
            messages: messages
        )
    }

    private func attachExistingAudioIfPossible(to card: FlashcardMO) -> Bool {
        if card.frontAudioFileName == nil, let backAudioFileName = card.backAudioFileName {
            card.frontAudioFileName = backAudioFileName
            card.updatedAt = Date()
            return true
        }

        if card.backAudioFileName == nil, let frontAudioFileName = card.frontAudioFileName {
            card.backAudioFileName = frontAudioFileName
            card.updatedAt = Date()
            return true
        }

        return false
    }
}
