import SwiftUI

enum AppPalette {
    static let ink = Color(red: 0.12, green: 0.14, blue: 0.15)
    static let tea = Color(red: 0.12, green: 0.40, blue: 0.34)
    static let teaSoft = Color(red: 0.90, green: 0.96, blue: 0.93)
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let amber = Color(red: 0.74, green: 0.47, blue: 0.16)
    static let cinnabar = Color(red: 0.72, green: 0.20, blue: 0.16)
    static let mist = Color(red: 0.92, green: 0.94, blue: 0.94)
}

struct AppScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(AppPalette.paper.ignoresSafeArea())
    }
}

struct AppListRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .padding(.vertical, 2)
            )
            .listRowSeparator(.hidden)
    }
}

struct MetricPill: View {
    let value: String
    let label: String
    var tint: Color = AppPalette.tea

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 62)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct LeadingSymbol: View {
    let systemImage: String
    var tint: Color = AppPalette.tea

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline)
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

extension View {
    func appScreenBackground() -> some View {
        modifier(AppScreenBackground())
    }

    func appListRow() -> some View {
        modifier(AppListRow())
    }
}
