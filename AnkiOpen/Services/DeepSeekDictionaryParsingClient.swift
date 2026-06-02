import Foundation

enum DeepSeekDictionaryParsingError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先在设置里填写 DeepSeek API Key。"
        case .invalidResponse:
            return "DeepSeek 没有返回可解析的词典结构。"
        case .server(let message):
            return message
        }
    }
}

struct DeepSeekDictionaryParsingClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func refine(
        entry: CZYZDDictionaryEntry,
        apiKey: String = DeepSeekSettingsStore.loadAPIKey(),
        model: DeepSeekModel = DeepSeekSettingsStore.selectedModel
    ) async throws -> CZYZDDictionaryEntry {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw DeepSeekDictionaryParsingError.missingAPIKey
        }

        var request = URLRequest(url: DeepSeekSettingsStore.baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            DeepSeekDictionaryChatRequest(
                model: model.rawValue,
                messages: messages(for: entry),
                thinking: ["type": "disabled"],
                responseFormat: ["type": "json_object"],
                temperature: 0,
                maxTokens: 450,
                stream: false
            )
        )

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw DeepSeekDictionaryParsingError.server(body)
        }

        let content = try parseMessageContent(from: data)
        return try Self.refinedEntry(from: content, fallback: entry)
    }

    static func refinedEntry(from content: String, fallback entry: CZYZDDictionaryEntry) throws -> CZYZDDictionaryEntry {
        let payload = try JSONDecoder().decode(DictionaryParsingPayload.self, from: Data(content.utf8))
        let parsedChaopin = CZYZDChaopinTextCleaner.romanizedChaopin(from: payload.chaopin)
        let fallbackChaopin = CZYZDChaopinTextCleaner.romanizedChaopin(from: entry.chaopin)
        let definition = cleanDefinition(payload.definition)
        let fallbackDefinition = cleanDefinition(entry.definition)

        return CZYZDDictionaryEntry(
            term: entry.term,
            chaopin: parsedChaopin ?? fallbackChaopin ?? "",
            chaopinImageURL: entry.chaopinImageURL,
            pronunciation: entry.pronunciation,
            definition: definition.isEmpty ? fallbackDefinition : definition,
            audioURL: entry.audioURL
        )
    }

    static func cleanDefinition(_ value: String) -> String {
        var cleanValue = value
            .replacingOccurrences(of: #"(?i)\b(?:chaopin|pengim|peng'im)\b\s*[:：]?\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"潮\s*拼\s*[:：]?\s*[A-Za-z0-9êÊṳṲⁿ⁰¹²³⁴⁵⁶⁷⁸⁹\- ]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"汉语拼音\s*[:：]?\s*[A-Za-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüńňǹḿ\s]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"拼\s*音\s*[:：]?\s*[A-Za-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüńňǹḿ\s]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "字义", with: "")
            .replacingOccurrences(of: "字 义", with: "")
            .replacingOccurrences(of: "词义", with: "")
            .replacingOccurrences(of: "詞義", with: "")
        cleanValue = cleanValue
            .replacingOccurrences(of: #"^[：:\s]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanValue
    }

    private func parseMessageContent(from data: Data) throws -> String {
        let response = try JSONDecoder().decode(DeepSeekDictionaryChatResponse.self, from: data)
        guard let content = response.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeepSeekDictionaryParsingError.invalidResponse
        }
        return content
    }

    private func messages(for entry: CZYZDDictionaryEntry) -> [DeepSeekDictionaryMessage] {
        [
            DeepSeekDictionaryMessage(
                role: "system",
                content: """
                你是潮汕话词典结构化助手。只返回合法 JSON，不要 Markdown。
                JSON 格式：{"chaopin":"...","definition":"..."}。
                chaopin 只能是潮拼/潮州话罗马字，例如 le2、uá2、zêg8；不能返回汉字、普通话拼音、字段名或解释。
                definition 只保留中文释义，不要“字义”“词义”“汉语拼音”“拼音”等标签，也不要音频、网页导航或多余说明。
                如果无法确定潮拼，chaopin 返回空字符串。
                """
            ),
            DeepSeekDictionaryMessage(
                role: "user",
                content: """
                词条：\(entry.term)
                当前潮拼文字：\(entry.chaopin)
                当前潮拼图片：\(entry.chaopinImageURL?.absoluteString ?? "")
                当前读音字段：\(entry.pronunciation)
                当前解释：\(entry.definition)

                请输出结构化 JSON。
                """
            )
        ]
    }
}

private struct DeepSeekDictionaryChatRequest: Encodable {
    let model: String
    let messages: [DeepSeekDictionaryMessage]
    let thinking: [String: String]
    let responseFormat: [String: String]
    let temperature: Double
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case thinking
        case responseFormat = "response_format"
        case temperature
        case maxTokens = "max_tokens"
        case stream
    }
}

private struct DeepSeekDictionaryMessage: Encodable {
    let role: String
    let content: String
}

private struct DeepSeekDictionaryChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ResponseMessage
    }

    struct ResponseMessage: Decodable {
        let content: String?
    }
}

private struct DictionaryParsingPayload: Decodable {
    let chaopin: String
    let definition: String
}
