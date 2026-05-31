import SwiftUI

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var backupURL: URL?
    @State private var errorMessage: String?

    private let backupExporter = BackupExporter()

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

                    if let backupURL {
                        ShareLink(item: backupURL) {
                            Label("Share Backup", systemImage: "square.and.arrow.up")
                        }
                        Text(backupURL.lastPathComponent)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Open Source") {
                    LabeledContent("License", value: "MIT")
                }
            }
            .navigationTitle("Settings")
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
}
