import SwiftUI

struct SettingsView: View {
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
                }

                Section("Open Source") {
                    LabeledContent("License", value: "MIT")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
