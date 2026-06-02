import Foundation

enum AudioFileStoreError: LocalizedError {
    case unsupportedFormat(String)
    case missingFile(String)
    case copyFailed(String)
    case restoreFailed(String)
    case storeDownloadedFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let name):
            return "\(name) 不是支持的音频格式。"
        case .missingFile(let name):
            return "CSV 引用了音频文件 \(name)，但导入时没有选择这个文件。"
        case .copyFailed(let name):
            return "无法把音频文件 \(name) 复制到本机存储。"
        case .restoreFailed(let name):
            return "无法从备份恢复音频文件 \(name)。"
        case .storeDownloadedFailed(let name):
            return "无法保存下载的音频文件 \(name)。"
        }
    }
}

enum AudioFileStore {
    static let supportedExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "caf", "aiff", "aif"]

    static func isSupportedAudioFile(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func localURL(for storedFileName: String) -> URL {
        audioDirectory().appendingPathComponent(storedFileName)
    }

    static func storedAudioExists(_ storedFileName: String?) -> Bool {
        guard let cleanName = cleanedStoredFileName(storedFileName) else {
            return false
        }
        return FileManager.default.fileExists(atPath: localURL(for: cleanName).path)
    }

    static func cleanedStoredFileName(_ storedFileName: String?) -> String? {
        guard let storedFileName else {
            return nil
        }
        let cleanName = URL(fileURLWithPath: storedFileName.trimmingCharacters(in: .whitespacesAndNewlines)).lastPathComponent
        return cleanName.isEmpty ? nil : cleanName
    }

    static func copyAudio(named fileName: String, from selectedFiles: [String: URL]) throws -> String {
        let cleanName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            return ""
        }

        let lookupName = URL(fileURLWithPath: cleanName).lastPathComponent
        guard supportedExtensions.contains(URL(fileURLWithPath: lookupName).pathExtension.lowercased()) else {
            throw AudioFileStoreError.unsupportedFormat(lookupName)
        }
        guard let sourceURL = selectedFiles[lookupName] else {
            throw AudioFileStoreError.missingFile(lookupName)
        }

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let storedName = "\(UUID().uuidString)-\(lookupName)"
        let destinationURL = localURL(for: storedName)
        do {
            try FileManager.default.createDirectory(
                at: audioDirectory(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return storedName
        } catch {
            throw AudioFileStoreError.copyFailed(lookupName)
        }
    }

    static func restoreAudio(storedFileName: String, data: Data) throws {
        let cleanName = URL(fileURLWithPath: storedFileName.trimmingCharacters(in: .whitespacesAndNewlines)).lastPathComponent
        guard !cleanName.isEmpty else {
            return
        }

        guard supportedExtensions.contains(URL(fileURLWithPath: cleanName).pathExtension.lowercased()) else {
            throw AudioFileStoreError.unsupportedFormat(cleanName)
        }

        let destinationURL = localURL(for: cleanName)
        do {
            try FileManager.default.createDirectory(
                at: audioDirectory(),
                withIntermediateDirectories: true
            )
            try data.write(to: destinationURL, options: [.atomic])
        } catch {
            throw AudioFileStoreError.restoreFailed(cleanName)
        }
    }

    static func storeDownloadedAudio(data: Data, suggestedFileName: String) throws -> String {
        try storeAudio(data: data, suggestedFileName: suggestedFileName)
    }

    static func storeAudio(data: Data, suggestedFileName: String) throws -> String {
        let cleanName = URL(fileURLWithPath: suggestedFileName.trimmingCharacters(in: .whitespacesAndNewlines)).lastPathComponent
        guard !cleanName.isEmpty else {
            return ""
        }

        guard supportedExtensions.contains(URL(fileURLWithPath: cleanName).pathExtension.lowercased()) else {
            throw AudioFileStoreError.unsupportedFormat(cleanName)
        }

        let storedName = "\(UUID().uuidString)-\(cleanName)"
        let destinationURL = localURL(for: storedName)
        do {
            try FileManager.default.createDirectory(
                at: audioDirectory(),
                withIntermediateDirectories: true
            )
            try data.write(to: destinationURL, options: [.atomic])
            return storedName
        } catch {
            throw AudioFileStoreError.storeDownloadedFailed(cleanName)
        }
    }

    private static func audioDirectory() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL.appendingPathComponent("Audio", isDirectory: true)
    }
}
