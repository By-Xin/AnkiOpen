import SwiftUI

struct ReportsView: View {
    @FetchRequest private var reports: FetchedResults<CardReportMO>
    @State private var filter: ReportStatusFilter = .open

    init() {
        let request = CardReportMO.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CardReportMO.createdAt, ascending: false)
        ]
        _reports = FetchRequest(fetchRequest: request, animation: .default)
    }

    private var filteredReports: [CardReportMO] {
        reports.filter { report in
            switch filter {
            case .open:
                return !report.isResolved
            case .resolved:
                return report.isResolved
            }
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Status", selection: $filter) {
                    ForEach(ReportStatusFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            if filteredReports.isEmpty {
                Section {
                    EmptyStateView(
                        title: filter.emptyTitle,
                        systemImage: filter.emptySystemImage,
                        message: filter.emptyMessage
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section(filter.title) {
                    ForEach(filteredReports) { report in
                        NavigationLink {
                            ReportDetailView(report: report)
                        } label: {
                            ReportRow(report: report)
                        }
                    }
                }
            }
        }
        .navigationTitle("Reports")
    }
}

private struct ReportRow: View {
    @ObservedObject var report: CardReportMO

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(report.categoryTitle, systemImage: report.isResolved ? "checkmark.circle" : "exclamationmark.bubble")
                    .font(.headline)
                Spacer()
                Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            FlashcardText(
                text: report.card.front,
                size: 15,
                relativeTo: .subheadline,
                weight: .regular,
                lineLimit: 1
            )
            .foregroundStyle(.primary)

            if !report.note.isEmpty {
                Text(report.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ReportDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var report: CardReportMO
    @State private var errorMessage: String?
    @State private var isShowingCardEditor = false

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Type", value: report.categoryTitle)
                LabeledContent("Created", value: report.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let resolvedAt = report.resolvedAt {
                    LabeledContent("Resolved", value: resolvedAt.formatted(date: .abbreviated, time: .shortened))
                } else {
                    LabeledContent("Resolved", value: "No")
                }
            }

            Section("Card") {
                LabeledContent("Notebook", value: report.card.notebook.name)
                if let unit = report.card.unit {
                    LabeledContent("Unit", value: unit.name)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Front")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlashcardText(text: report.card.front, size: 17, relativeTo: .body, weight: .regular)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Back")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlashcardText(text: report.card.back, size: 17, relativeTo: .body, weight: .regular)
                }

                Button {
                    isShowingCardEditor = true
                } label: {
                    Label("Edit Card", systemImage: "pencil")
                }
            }

            if !report.note.isEmpty {
                Section("Note") {
                    Text(report.note)
                }
            }

            Section {
                Button {
                    toggleResolved()
                } label: {
                    Label(report.isResolved ? "Reopen Report" : "Mark Resolved", systemImage: report.isResolved ? "arrow.uturn.backward" : "checkmark.circle")
                }
            }
        }
        .navigationTitle("Report")
        .sheet(isPresented: $isShowingCardEditor) {
            CardEditorView(mode: .edit(report.card))
        }
        .alert("Report Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private func toggleResolved() {
        if report.isResolved {
            report.reopen()
        } else {
            report.markResolved()
        }

        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private enum ReportStatusFilter: String, CaseIterable, Identifiable {
    case open
    case resolved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open:
            return "Open"
        case .resolved:
            return "Resolved"
        }
    }

    var emptyTitle: String {
        switch self {
        case .open:
            return "No Open Reports"
        case .resolved:
            return "No Resolved Reports"
        }
    }

    var emptySystemImage: String {
        switch self {
        case .open:
            return "checkmark.circle"
        case .resolved:
            return "tray"
        }
    }

    var emptyMessage: String {
        switch self {
        case .open:
            return "New card issue reports will appear here until they are marked resolved."
        case .resolved:
            return "Resolved card issue reports will appear here for later review."
        }
    }
}
