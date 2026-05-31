import CoreData
import SwiftUI

@main
struct AnkiOpenApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    #if DEBUG
                    DebugLaunchCSVImporter.importIfRequested(context: persistenceController.container.viewContext)
                    #endif
                }
        }
    }
}

#if DEBUG
private enum DebugLaunchCSVImporter {
    private static var didCheckEnvironment = false

    static func importIfRequested(context: NSManagedObjectContext) {
        guard !didCheckEnvironment else {
            return
        }
        didCheckEnvironment = true

        let environment = ProcessInfo.processInfo.environment
        guard let base64CSV = environment["ANKIOPEN_DEBUG_IMPORT_CSV_BASE64"],
              let data = Data(base64Encoded: base64CSV),
              !data.isEmpty else {
            return
        }

        let requestedNotebookName = environment["ANKIOPEN_DEBUG_IMPORT_NOTEBOOK"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let notebookName = requestedNotebookName?.isEmpty == false ? requestedNotebookName! : "Debug Import"

        do {
            let csvURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("ankiopen-debug-import-\(UUID().uuidString)")
                .appendingPathExtension("csv")
            try data.write(to: csvURL, options: [.atomic])
            let notebook = try findOrCreateNotebook(named: notebookName, context: context)
            let summary = try CSVImporter().import(url: csvURL, into: notebook, context: context)
            try context.save()
            try? FileManager.default.removeItem(at: csvURL)
            print("Debug CSV import completed: \(summary.importedRows) imported, \(summary.skippedRows) skipped.")
        } catch {
            context.rollback()
            print("Debug CSV import failed: \(error.localizedDescription)")
        }
    }

    private static func findOrCreateNotebook(named rawName: String, context: NSManagedObjectContext) throws -> NotebookMO {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = NotebookMO.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        if let notebook = try context.fetch(request).first {
            return notebook
        }

        let now = Date()
        let notebook = NotebookMO(context: context)
        notebook.id = UUID()
        notebook.name = name
        notebook.createdAt = now
        notebook.updatedAt = now
        return notebook
    }
}
#endif
