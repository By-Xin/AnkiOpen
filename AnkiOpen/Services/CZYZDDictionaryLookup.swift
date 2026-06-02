import Foundation

struct CZYZDDictionaryEntry: Identifiable, Equatable {
    let id = UUID()
    let term: String
    let chaopin: String
    let chaopinImageURL: URL?
    let pronunciation: String
    let definition: String
    let audioURL: URL?

    init(
        term: String,
        chaopin: String = "",
        chaopinImageURL: URL? = nil,
        pronunciation: String = "",
        definition: String,
        audioURL: URL?
    ) {
        self.term = term
        self.chaopin = chaopin
        self.chaopinImageURL = chaopinImageURL
        self.pronunciation = pronunciation
        self.definition = definition
        self.audioURL = audioURL
    }
}

enum CZYZDDictionaryLookupError: LocalizedError {
    case invalidSearchURL
    case invalidResponse
    case invalidHTML

    var errorDescription: String? {
        switch self {
        case .invalidSearchURL:
            return "无法生成潮语词典搜索地址。"
        case .invalidResponse:
            return "潮语词典搜索返回异常。"
        case .invalidHTML:
            return "潮语词典页面无法读取。"
        }
    }
}

final class CZYZDDictionaryLookup {
    private let session: URLSession
    private let entryRefiner: CZYZDDictionaryEntryRefining?

    init(
        session: URLSession = .shared,
        entryRefiner: CZYZDDictionaryEntryRefining? = CZYZDDefaultDictionaryEntryRefiner()
    ) {
        self.session = session
        self.entryRefiner = entryRefiner
    }

    func lookup(term: String) async throws -> [CZYZDDictionaryEntry] {
        guard let url = CZYZDAudioResolver.searchURL(for: term) else {
            throw CZYZDDictionaryLookupError.invalidSearchURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("http://www.czyzd.com/", forHTTPHeaderField: "Referer")
        request.setValue("AnkiOpen/0.1 CZYZD Dictionary Lookup", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw CZYZDDictionaryLookupError.invalidResponse
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw CZYZDDictionaryLookupError.invalidHTML
        }

        let parsedEntries = Self.entries(in: html, matching: term)
        guard let entryRefiner else {
            return parsedEntries
        }
        return await entryRefiner.refine(parsedEntries)
    }

    static func entries(in html: String, matching term: String) -> [CZYZDDictionaryEntry] {
        let normalizedTerm = normalizedLookupText(term)
        let entries = dictionaryEntries(in: html).map(parseEntry)
        guard !normalizedTerm.isEmpty else {
            return entries
        }

        let exact = entries.filter { normalizedLookupText($0.term) == normalizedTerm }
        if !exact.isEmpty {
            return exact
        }

        if normalizedTerm.count == 1 {
            return entries
        }

        return entries.filter { normalizedLookupText($0.term).contains(normalizedTerm) }
    }

    private static func parseEntry(_ raw: RawEntry) -> CZYZDDictionaryEntry {
        let plainText = strippedHTML(raw.html)
        let chaopin = chaopin(in: raw.html)
        let pronunciation = chaopin.text.isEmpty && chaopin.imageURL == nil
            ? pronunciation(in: raw.html, plainText: plainText, term: raw.term)
            : chaopin.text
        let definition = definition(in: raw.html, plainText: plainText, term: raw.term, pronunciation: pronunciation)
        let resolvedChaopin = chaopin.text.isEmpty
            ? chaopinFromDefinition(in: plainText)
            : chaopin.text
        return CZYZDDictionaryEntry(
            term: raw.term,
            chaopin: resolvedChaopin,
            chaopinImageURL: chaopin.imageURL,
            pronunciation: pronunciation,
            definition: definition,
            audioURL: CZYZDAudioResolver.firstAudioURL(in: raw.html)
        )
    }

    private static func chaopin(in html: String) -> (text: String, imageURL: URL?) {
        guard let row = firstCapture(pattern: #"(?is)<li>\s*<b>\s*潮州音\s*[:：]?\s*</b>(.*?)</li>"#, in: html) ??
                firstCapture(pattern: #"(?is)<li>\s*<b>\s*潮州音.*?</b>(.*?)</li>"#, in: html) else {
            return ("", nil)
        }

        let imageHTML = firstCapture(pattern: #"(?is)(<img\b[^>]*>)"#, in: row)
        let title = imageHTML.flatMap { attribute("title", in: $0) }
        let alt = imageHTML.flatMap { attribute("alt", in: $0) }
        let src = imageHTML.flatMap { attribute("src", in: $0) }
        let text = CZYZDChaopinTextCleaner.romanizedChaopin(from: cleanedBracketText(title ?? alt ?? "")) ?? ""
        return (text, absoluteURL(from: src))
    }

    private static func pronunciation(in html: String, plainText: String, term: String) -> String {
        let htmlPatterns = [
            #"(?is)<[^>]*(?:class|id)=["'][^"']*(?:pinyin|pron|jyut|peng|sound)[^"']*["'][^>]*>(.*?)</[^>]+>"#
        ]
        for pattern in htmlPatterns {
            if let value = firstCapture(pattern: pattern, in: html) {
                let cleanValue = strippedHTML(value)
                if !cleanValue.isEmpty {
                    return cleanValue
                }
            }
        }

        let textPatterns = [
            #"(?i)(?:拼音|读音|發音|发音|音标|聲調|声调)\s*[:：]\s*([A-Za-z0-9\sˊˋ˙¯\-]+)"#,
            #"\[\s*([^\[\]]{1,40})\s*\]"#,
            #"\(\s*([^()]{1,40})\s*\)"#
        ]
        for pattern in textPatterns {
            if let value = firstCapture(pattern: pattern, in: plainText), value != term {
                return value
            }
        }

        return ""
    }

    private static func definition(in html: String, plainText: String, term: String, pronunciation: String) -> String {
        let definitionPatterns = [
            #"(?is)<li>\s*<b>\s*(?:字|词|詞)(?:&nbsp;|\s|　)*义\s*[:：]?\s*</b>\s*(.*?)</li>"#,
            #"(?is)<li>\s*<b>\s*(?:释义|解释|意思)\s*[:：]?\s*</b>\s*(.*?)</li>"#
        ]

        for pattern in definitionPatterns {
            if let value = firstCapture(pattern: pattern, in: html) {
                let cleanValue = cleanupDefinition(strippedHTML(value), term: term, pronunciation: pronunciation)
                if !cleanValue.isEmpty {
                    return cleanValue
                }
            }
        }

        return cleanupDefinition(plainText, term: term, pronunciation: pronunciation)
    }

    private static func chaopinFromDefinition(in plainText: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"\|\|\s*([\p{Latin}0-9ⁿ'\-]+)"#,
            options: [.caseInsensitive]
        ) else {
            return ""
        }

        let range = NSRange(plainText.startIndex..<plainText.endIndex, in: plainText)
        let values = regex.matches(in: plainText, range: range).compactMap { match -> String? in
            guard let valueRange = Range(match.range(at: 1), in: plainText) else {
                return nil
            }
            return String(plainText[valueRange])
        }

        return CZYZDChaopinTextCleaner.romanizedChaopin(from: values.joined(separator: " ")) ?? ""
    }

    private static func cleanupDefinition(_ plainText: String, term: String, pronunciation: String) -> String {
        var value = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !term.isEmpty, value.hasPrefix(term) {
            value.removeFirst(term.count)
        }

        value = value
            .replacingOccurrences(of: pronunciation, with: "")
            .replacingOccurrences(of: #"潮州音\s*[:：]?\s*\S+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"潮阳音\s*[:：]?\s*\S+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"普宁音\s*[:：]?\s*\S+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"惠来音\s*[:：]?\s*\S+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"陆丰音\s*[:：]?\s*\S+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"海丰音\s*[:：]?\s*\S+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"潮\s*拼\s*[:：]?\s*[\p{Latin}0-9ⁿ'\- ]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\b\d+\.\s*[\p{Latin}0-9\s]+\|\|[\p{Latin}0-9ⁿ'\-]+\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[\p{Latin}0-9\s]+\|\|[\p{Latin}0-9ⁿ'\-]+\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"汉语拼音\s*[:：]?\s*[\p{Latin}0-9\s]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"拼\s*音\s*[:：]?\s*[\p{Latin}0-9\s]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "拼音", with: "")
            .replacingOccurrences(of: "读音", with: "")
            .replacingOccurrences(of: "發音", with: "")
            .replacingOccurrences(of: "发音", with: "")
            .replacingOccurrences(of: "字义", with: "")
            .replacingOccurrences(of: "字 义", with: "")
            .replacingOccurrences(of: "词义", with: "")
            .replacingOccurrences(of: "詞義", with: "")
        value = value.replacingOccurrences(of: #"[:：\[\]()]+"#, with: " ", options: .regularExpression)
        return collapsedWhitespace(value)
    }

    private static func dictionaryEntries(in html: String) -> [RawEntry] {
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
            return RawEntry(term: decodedHTMLText(String(html[titleRange])), html: String(html[blockRange]))
        }
    }

    private static func strippedHTML(_ value: String) -> String {
        let withoutTags = decodedHTMLText(value)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        return collapsedWhitespace(withoutTags)
    }

    private static func firstCapture(pattern: String, in value: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: value) else {
            return nil
        }
        let captured = collapsedWhitespace(String(value[captureRange]))
        return captured.isEmpty ? nil : captured
    }

    private static func attribute(_ name: String, in html: String) -> String? {
        firstCapture(pattern: #"\b\#(name)\s*=\s*["']([^"']+)["']"#, in: html).map(decodedHTMLText)
    }

    private static func cleanedBracketText(_ value: String) -> String {
        decodedHTMLText(value)
            .replacingOccurrences(of: #"^[\[\(（【]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*[\]\)）】]$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(\d)"#, with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func absoluteURL(from value: String?) -> URL? {
        guard let value, !value.isEmpty else {
            return nil
        }
        if let url = URL(string: value), url.scheme != nil {
            return url
        }
        return URL(string: value, relativeTo: URL(string: "https://api.czyzd.com"))?.absoluteURL
    }

    private static func collapsedWhitespace(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
}

private struct RawEntry {
    let term: String
    let html: String
}

protocol CZYZDDictionaryEntryRefining {
    func refine(_ entries: [CZYZDDictionaryEntry]) async -> [CZYZDDictionaryEntry]
}

final class CZYZDDefaultDictionaryEntryRefiner: CZYZDDictionaryEntryRefining {
    private let chaopinResolver: CZYZDChaopinImageTextResolver
    private let deepSeekParser: DeepSeekDictionaryParsingClient

    init(
        chaopinResolver: CZYZDChaopinImageTextResolver = CZYZDChaopinImageTextResolver(),
        deepSeekParser: DeepSeekDictionaryParsingClient = DeepSeekDictionaryParsingClient()
    ) {
        self.chaopinResolver = chaopinResolver
        self.deepSeekParser = deepSeekParser
    }

    func refine(_ entries: [CZYZDDictionaryEntry]) async -> [CZYZDDictionaryEntry] {
        var refinedEntries: [CZYZDDictionaryEntry] = []
        refinedEntries.reserveCapacity(entries.count)

        for entry in entries {
            var refinedEntry = await refineChaopinImageIfNeeded(entry)

            if DeepSeekSettingsStore.isDictionaryParsingEnabled,
               !DeepSeekSettingsStore.loadAPIKey().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let parsedEntry = try? await deepSeekParser.refine(entry: refinedEntry) {
                refinedEntry = parsedEntry
            }

            refinedEntries.append(refinedEntry)
        }

        return refinedEntries
    }

    private func refineChaopinImageIfNeeded(_ entry: CZYZDDictionaryEntry) async -> CZYZDDictionaryEntry {
        guard entry.chaopin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let imageURL = entry.chaopinImageURL,
              let chaopin = await chaopinResolver.resolveText(from: imageURL) else {
            return entry
        }

        return CZYZDDictionaryEntry(
            term: entry.term,
            chaopin: chaopin,
            chaopinImageURL: entry.chaopinImageURL,
            pronunciation: entry.pronunciation,
            definition: entry.definition,
            audioURL: entry.audioURL
        )
    }
}
