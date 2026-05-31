import Foundation

enum AudioFileStoreError: LocalizedError {
    case unsupportedFormat(String)
    case missingFile(String)
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let name):
            return "\(name) is not a supported audio format."
        case .missingFile(let name):
            return "Audio file \(name) was referenced by the CSV but not selected."
        case .copyFailed(let name):
            return "Could not copy audio file \(name) into local storage."
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

    private static func audioDirectory() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL.appendingPathComponent("Audio", isDirectory: true)
    }
}
