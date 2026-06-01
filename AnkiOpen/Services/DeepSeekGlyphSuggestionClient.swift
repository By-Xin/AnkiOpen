import Foundation

enum DeepSeekGlyphSuggestionError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptySuggestion
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add a DeepSeek API key in Settings first."
        case .invalidResponse:
            return "DeepSeek returned an unreadable response."
        case .emptySuggestion:
            return "DeepSeek did not return a replacement suggestion."
        case .server(let message):
            return message
        }
    }
}

struct DeepSeekGlyphSuggestionClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func suggestReplacement(
        for scalar: UnicodeScalar,
        examples: [String],
        apiKey: String = DeepSeekSettingsStore.loadAPIKey(),
        model: DeepSeekModel = DeepSeekSettingsStore.selectedModel
    ) async throws -> GlyphReplacementSuggestion {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw DeepSeekGlyphSuggestionError.missingAPIKey
        }

        var request = URLRequest(url: DeepSeekSettingsStore.baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(
                model: model.rawValue,
                messages: messages(for: scalar, examples: examples),
                thinking: ["type": "disabled"],
                responseFormat: ["type": "json_object"],
                temperature: 0.1,
                maxTokens: 300,
                stream: false
            )
        )

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw DeepSeekGlyphSuggestionError.server(body)
        }

        let content = try parseMessageContent(from: data)
        return try Self.parseSuggestionContent(content, scalar: scalar)
    }

    static func parseSuggestionContent(_ content: String, scalar: UnicodeScalar) throws -> GlyphReplacementSuggestion {
        let data = Data(content.utf8)
        let payload = try JSONDecoder().decode(SuggestionPayload.self, from: data)
        let replacement = payload.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !replacement.isEmpty else {
            throw DeepSeekGlyphSuggestionError.emptySuggestion
        }
        return GlyphReplacementSuggestion(
            scalarValue: scalar.value,
            glyph: String(scalar),
            replacement: replacement,
            explanation: payload.explanation.trimmingCharacters(in: .whitespacesAndNewlines),
            updatedAt: Date()
        )
    }

    private func parseMessageContent(from data: Data) throws -> String {
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = response.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeepSeekGlyphSuggestionError.invalidResponse
        }
        return content
    }

    private func messages(for scalar: UnicodeScalar, examples: [String]) -> [Message] {
        let clippedExamples = examples
            .prefix(8)
            .map { String($0.prefix(80)) }
            .joined(separator: "\n")

        return [
            Message(
                role: "system",
                content: """
                You help normalize rare Han characters for a Teochew/Chaoshan flashcard app. Return only valid JSON.
                Choose a practical replacement that is easy to display on iOS while preserving the likely meaning.
                JSON shape: {"replacement":"...", "explanation":"short reason"}
                """
            ),
            Message(
                role: "user",
                content: """
                Rare glyph: \(String(scalar))
                Code point: U+\(String(scalar.value, radix: 16).uppercased())
                Card examples:
                \(clippedExamples)
                Suggest one replacement character or short phrase. If uncertain, choose the closest practical standard Chinese substitute and say why.
                """
            )
        ]
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [Message]
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

private struct Message: Encodable {
    let role: String
    let content: String
}

private struct ChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ResponseMessage
    }

    struct ResponseMessage: Decodable {
        let content: String?
    }
}

private struct SuggestionPayload: Decodable {
    let replacement: String
    let explanation: String
}
