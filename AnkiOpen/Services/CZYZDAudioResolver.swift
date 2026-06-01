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

final class CZYZDAudioResolver {
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

        return Self.firstAudioURL(in: html)
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

    private static func safeFileStem(for term: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let clean = term
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
        let stem = String(clean).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return stem.isEmpty ? "czyzd-audio" : stem
    }

    private static let userAgent = "AnkiOpen/0.1 CZYZD Audio Import"
}

@MainActor
final class CZYZDAudioAttachmentService {
    private let resolver: CZYZDAudioResolver

    init(resolver: CZYZDAudioResolver = CZYZDAudioResolver()) {
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
            format: "id IN %@ AND frontAudioFileName == nil AND isArchived == NO",
            cardIDs
        )

        let cards: [FlashcardMO]
        do {
            cards = try context.fetch(request)
        } catch {
            return CZYZDAudioAttachmentSummary(
                checkedCards: 0,
                matchedCards: 0,
                failedCards: cardIDs.count,
                messages: ["Could not load imported cards for CZYZD matching."]
            )
        }

        var matched = 0
        var failed = 0
        var messages: [String] = []

        for card in cards {
            do {
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
}
