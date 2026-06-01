import SwiftUI

struct FlashcardText: View {
    let text: String
    let size: CGFloat
    let relativeTo: Font.TextStyle
    let weight: Font.Weight
    var alignment: TextAlignment = .leading
    var lineLimit: Int?

    var body: some View {
        Text(text)
            .flashcardCJKFont(size: size, relativeTo: relativeTo, weight: weight)
            .lineSpacing(5)
            .multilineTextAlignment(alignment)
            .lineLimit(lineLimit)
    }
}

extension View {
    func flashcardCJKFont(
        size: CGFloat,
        relativeTo: Font.TextStyle,
        weight: Font.Weight = .regular
    ) -> some View {
        font(.custom(FlashcardFont.postScriptName(for: weight), size: size, relativeTo: relativeTo))
    }
}

private enum FlashcardFont {
    static func postScriptName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black, .semibold:
            return "PingFangSC-Semibold"
        case .medium:
            return "PingFangSC-Medium"
        default:
            return "PingFangSC-Regular"
        }
    }
}
