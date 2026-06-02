import Foundation
import Security

enum DeepSeekModel: String, CaseIterable, Identifiable {
    case flash = "deepseek-v4-flash"
    case pro = "deepseek-v4-pro"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flash:
            return "V4 Flash"
        case .pro:
            return "V4 Pro"
        }
    }
}

enum DeepSeekSettingsStore {
    static let baseURL = URL(string: "https://api.deepseek.com/chat/completions")!

    private static let apiKeyService = "com.xinby.AnkiOpen.deepseek"
    private static let apiKeyAccount = "api-key"
    private static let modelKey = "deepseek.model"
    private static let dictionaryParsingKey = "deepseek.dictionaryParsingEnabled"

    static var selectedModel: DeepSeekModel {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: modelKey),
                  let model = DeepSeekModel(rawValue: rawValue) else {
                return .flash
            }
            return model
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modelKey)
        }
    }

    static var isDictionaryParsingEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: dictionaryParsingKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: dictionaryParsingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dictionaryParsingKey)
        }
    }

    static func loadAPIKey() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }
        return value
    }

    static func saveAPIKey(_ value: String) throws {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanValue.isEmpty {
            deleteAPIKey()
            return
        }

        let data = Data(cleanValue.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: apiKeyAccount
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }

        guard status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError(status: addStatus)
        }
    }

    static func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: apiKeyAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        "钥匙串写入失败，错误码 \(status)。"
    }
}

struct GlyphReplacementSuggestion: Codable, Equatable {
    let scalarValue: UInt32
    let glyph: String
    let replacement: String
    let explanation: String
    let updatedAt: Date
}

enum GlyphReplacementSuggestionStore {
    private static let key = "glyph.replacement.suggestions"

    static func suggestion(for scalar: UnicodeScalar) -> GlyphReplacementSuggestion? {
        all()[scalar.value]
    }

    static func save(_ suggestion: GlyphReplacementSuggestion) {
        var values = all()
        values[suggestion.scalarValue] = suggestion
        save(values)
    }

    static func all() -> [UInt32: GlyphReplacementSuggestion] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let values = try? JSONDecoder().decode([UInt32: GlyphReplacementSuggestion].self, from: data) else {
            return [:]
        }
        return values
    }

    private static func save(_ values: [UInt32: GlyphReplacementSuggestion]) {
        guard let data = try? JSONEncoder().encode(values) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}
