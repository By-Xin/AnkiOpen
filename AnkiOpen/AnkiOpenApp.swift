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
                    migrateLegacyUnitNames()
                    #if DEBUG
                    DebugLaunchCSVImporter.importIfRequested(context: persistenceController.container.viewContext)
                    #endif
                }
        }
    }

    private func migrateLegacyUnitNames() {
        do {
            try NotebookUnitMO.migrateLegacyEnglishNames(context: persistenceController.container.viewContext)
        } catch {
            persistenceController.container.viewContext.rollback()
            print("Unit name migration failed: \(error.localizedDescription)")
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
        guard let source = makeSourceCSVURL(from: environment) else {
            return
        }

        let requestedNotebookName = environment["ANKIOPEN_DEBUG_IMPORT_NOTEBOOK"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let notebookName = requestedNotebookName?.isEmpty == false ? requestedNotebookName! : "Debug Import"

        do {
            let fileSize = try fileSize(at: source.url)
            let previewRows = try parsedRowCount(at: source.url)
            let notebook = try findOrCreateNotebook(named: notebookName, context: context)
            let summary = try CSVImporter().import(url: source.url, into: notebook, context: context)
            try context.save()
            if source.shouldRemoveAfterImport {
                try? FileManager.default.removeItem(at: source.url)
            }
            writeStatus(
                "success\nurl=\(source.url.path)\nfileSize=\(fileSize)\nparsedRows=\(previewRows)\ntotalRows=\(summary.totalRows)\nimportedRows=\(summary.importedRows)\nskippedRows=\(summary.skippedRows)"
            )
            print("Debug CSV import completed: \(summary.importedRows) imported, \(summary.skippedRows) skipped.")
        } catch {
            context.rollback()
            writeStatus("failure\nurl=\(source.url.path)\nerror=\(error.localizedDescription)")
            print("Debug CSV import failed: \(error.localizedDescription)")
        }
    }

    private static func makeSourceCSVURL(from environment: [String: String]) -> (url: URL, shouldRemoveAfterImport: Bool)? {
        if let documentName = environment["ANKIOPEN_DEBUG_IMPORT_CSV_DOCUMENT_NAME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !documentName.isEmpty,
           let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileName = URL(fileURLWithPath: documentName).lastPathComponent
            return (documentsURL.appendingPathComponent(fileName), false)
        }

        guard let base64CSV = environment["ANKIOPEN_DEBUG_IMPORT_CSV_BASE64"],
              let data = Data(base64Encoded: base64CSV),
              !data.isEmpty else {
            return nil
        }

        do {
            let csvURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("ankiopen-debug-import-\(UUID().uuidString)")
                .appendingPathExtension("csv")
            try data.write(to: csvURL, options: [.atomic])
            return (csvURL, true)
        } catch {
            print("Debug CSV import failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func fileSize(at url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values.fileSize ?? 0)
    }

    private static func parsedRowCount(at url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        guard let contents = String(data: data, encoding: .utf8) else {
            return -1
        }
        return CSVParser.parse(contents).count
    }

    private static func writeStatus(_ contents: String) {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let statusURL = documentsURL.appendingPathComponent("ankiopen-debug-import-status.txt")
        try? contents.write(to: statusURL, atomically: true, encoding: .utf8)
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
