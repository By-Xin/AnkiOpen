import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var reports: FetchedResults<CardReportMO>
    @State private var backupURL: URL?
    @State private var importSummary: BackupImportSummary?
    @State private var isShowingBackupImporter = false
    @State private var errorMessage: String?

    private let backupExporter = BackupExporter()
    private let backupImporter = BackupImporter()

    init() {
        let request = CardReportMO.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CardReportMO.createdAt, ascending: false)]
        _reports = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Review Scheduler") {
                    LabeledContent("Algorithm", value: "FSRS")
                    LabeledContent("Retention", value: "0.90")
                    LabeledContent("Version", value: "FSRS-6 defaults")
                }

                Section("Data") {
                    LabeledContent("Storage", value: "Local Core Data")
                    LabeledContent("Sync", value: "Off")

                    Button {
                        createBackup()
                    } label: {
                        Label("Create JSON Backup", systemImage: "externaldrive.badge.timemachine")
                    }

                    Button {
                        isShowingBackupImporter = true
                    } label: {
                        Label("Import JSON Backup", systemImage: "tray.and.arrow.down")
                    }

                    if let backupURL {
                        ShareLink(item: backupURL) {
                            Label("Share Backup", systemImage: "square.and.arrow.up")
                        }
                        Text(backupURL.lastPathComponent)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let importSummary {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Restore")
                                .font(.headline)
                            Text(importSummary.fileName)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text("\(importSummary.importedNotebooks) notebooks, \(importSummary.importedUnits) units, \(importSummary.importedCards) cards, \(importSummary.importedReviewLogs) logs")
                                .font(.footnote)
                            Text("\(importSummary.importedMediaFiles) media files restored")
                                .font(.footnote)
                            Text("\(importSummary.skippedDuplicates) duplicates skipped")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Reports") {
                    LabeledContent("Local reports", value: "\(reports.count)")
                    Text("Reports are saved locally for now. Cloud submission/export can be added after the correction workflow is stable.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Open Source") {
                    LabeledContent("License", value: "MIT")
                }
            }
            .navigationTitle("Settings")
            .fileImporter(
                isPresented: $isShowingBackupImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                importBackup(result)
            }
            .alert("Backup Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private func createBackup() {
        do {
            backupURL = try backupExporter.writeBackup(context: viewContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importBackup(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }
            importSummary = try backupImporter.import(url: url, context: viewContext)
            try viewContext.save()
        } catch {
            viewContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
