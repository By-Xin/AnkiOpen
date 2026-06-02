import Foundation

#if canImport(UIKit) && canImport(Vision)
import UIKit
@preconcurrency import Vision
#endif

enum CZYZDChaopinTextCleaner {
    static func romanizedChaopin(from rawValue: String) -> String? {
        let normalized = rawValue
            .replacingOccurrences(of: "¹", with: "1")
            .replacingOccurrences(of: "²", with: "2")
            .replacingOccurrences(of: "³", with: "3")
            .replacingOccurrences(of: "⁴", with: "4")
            .replacingOccurrences(of: "⁵", with: "5")
            .replacingOccurrences(of: "⁶", with: "6")
            .replacingOccurrences(of: "⁷", with: "7")
            .replacingOccurrences(of: "⁸", with: "8")
            .replacingOccurrences(of: "⁹", with: "9")
            .replacingOccurrences(of: "⁰", with: "0")
            .replacingOccurrences(of: #"[\[\]（）()【】]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tokens = normalized
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" || $0 == "，" || $0 == "；" })
            .map(String.init)

        return tokens.first(where: isLikelyRomanizedChaopin)
    }

    static func isLikelyRomanizedChaopin(_ value: String) -> Bool {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanValue.isEmpty else {
            return false
        }
        guard cleanValue.range(of: #"\p{Han}"#, options: .regularExpression) == nil else {
            return false
        }
        guard cleanValue.range(of: #"[A-Za-zêÊṳṲⁿ]"#, options: .regularExpression) != nil else {
            return false
        }
        return cleanValue.range(
            of: #"^[A-Za-z0-9êÊṳṲⁿ⁰¹²³⁴⁵⁶⁷⁸⁹\-]+$"#,
            options: .regularExpression
        ) != nil
    }
}

final class CZYZDChaopinImageTextResolver {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func resolveText(from imageURL: URL) async -> String? {
#if canImport(UIKit) && canImport(Vision)
        do {
            var request = URLRequest(url: imageURL)
            request.timeoutInterval = 20
            request.setValue("http://www.czyzd.com/", forHTTPHeaderField: "Referer")
            request.setValue("AnkiOpen/0.1 CZYZD Chaopin OCR", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let image = UIImage(data: data)?.cgImage else {
                return nil
            }

            let recognizedText = try await recognizeText(in: image)
            return CZYZDChaopinTextCleaner.romanizedChaopin(from: recognizedText)
        } catch {
            return nil
        }
#else
        return nil
#endif
    }

#if canImport(UIKit) && canImport(Vision)
    private func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let values = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: values.joined(separator: " "))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = false

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
#endif
}
