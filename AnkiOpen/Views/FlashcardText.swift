import SwiftUI

struct FlashcardText: View {
    let text: String
    let size: CGFloat
    let relativeTo: Font.TextStyle
    let weight: Font.Weight
    var alignment: TextAlignment = .leading
    var lineLimit: Int?

    var body: some View {
        if GlyphFallbackAsset.containsFallbacks(text) {
            GlyphFallbackText(
                text: text,
                size: size,
                relativeTo: relativeTo,
                weight: weight,
                alignment: alignment,
                lineLimit: lineLimit
            )
        } else {
            Text(text)
                .flashcardCJKFont(size: size, relativeTo: relativeTo, weight: weight)
                .lineSpacing(5)
                .multilineTextAlignment(alignment)
                .lineLimit(lineLimit)
        }
    }
}

private struct GlyphFallbackText: View {
    let text: String
    let size: CGFloat
    let relativeTo: Font.TextStyle
    let weight: Font.Weight
    let alignment: TextAlignment
    let lineLimit: Int?

    var body: some View {
        GlyphFlowLayout(spacing: max(1, size * 0.03), lineSpacing: 5, alignment: alignment) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                if let imageName = GlyphFallbackAsset.imageName(for: character) {
                    Image(imageName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.primary)
                        .frame(width: size * 1.08, height: size * 1.08)
                        .accessibilityLabel(Text(String(character)))
                } else {
                    Text(String(character))
                        .flashcardCJKFont(size: size, relativeTo: relativeTo, weight: weight)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: horizontalAlignment)
        .lineLimit(lineLimit)
    }

    private var horizontalAlignment: Alignment {
        switch alignment {
        case .center:
            return .center
        case .trailing:
            return .trailing
        default:
            return .leading
        }
    }
}

private struct GlyphFlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let alignment: TextAlignment

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layout(in: proposal.width ?? .greatestFiniteMagnitude, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(in: bounds.width, subviews: subviews)
        for line in result.lines {
            let xOffset: CGFloat
            switch alignment {
            case .center:
                xOffset = (bounds.width - line.size.width) / 2
            case .trailing:
                xOffset = bounds.width - line.size.width
            default:
                xOffset = 0
            }

            for item in line.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + xOffset + item.origin.x, y: bounds.minY + item.origin.y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> LayoutResult {
        var lines: [LayoutLine] = []
        var items: [LayoutItem] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        let availableWidth = max(1, width)

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if currentX > 0, currentX + size.width > availableWidth {
                lines.append(LayoutLine(items: items, size: CGSize(width: max(0, currentX - spacing), height: lineHeight)))
                maxWidth = max(maxWidth, currentX - spacing)
                currentY += lineHeight + lineSpacing
                currentX = 0
                lineHeight = 0
                items = []
            }

            items.append(LayoutItem(index: index, origin: CGPoint(x: currentX, y: currentY), size: size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        if !items.isEmpty {
            lines.append(LayoutLine(items: items, size: CGSize(width: max(0, currentX - spacing), height: lineHeight)))
            maxWidth = max(maxWidth, currentX - spacing)
        }

        let height = lines.last.map { line in
            (line.items.first?.origin.y ?? 0) + line.size.height
        } ?? 0
        return LayoutResult(lines: lines, size: CGSize(width: min(maxWidth, availableWidth), height: height))
    }
}

private struct LayoutResult {
    let lines: [LayoutLine]
    let size: CGSize
}

private struct LayoutLine {
    let items: [LayoutItem]
    let size: CGSize
}

private struct LayoutItem {
    let index: Int
    let origin: CGPoint
    let size: CGSize
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
