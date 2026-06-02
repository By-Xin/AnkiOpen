import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let notebook = NotebookMO(context: context)
        notebook.id = UUID()
        notebook.name = "Biology"
        notebook.createdAt = Date()
        notebook.updatedAt = Date()

        let unit = NotebookUnitMO.insert(name: "单元 1", notebook: notebook, context: context)
        _ = FlashcardMO.insert(
            front: "What is spaced repetition?",
            back: "A learning technique that schedules reviews over increasing intervals.",
            unit: unit,
            context: context
        )
        try? context.save()
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "AnkiOpen", managedObjectModel: CoreDataModelFactory.makeModel())

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.persistentStoreDescriptions.forEach { description in
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Unresolved Core Data error: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
