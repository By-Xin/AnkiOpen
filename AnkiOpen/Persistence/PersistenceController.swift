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

        let card = FlashcardMO(context: context)
        card.id = UUID()
        card.front = "What is spaced repetition?"
        card.back = "A learning technique that schedules reviews over increasing intervals."
        card.frontAudioFileName = nil
        card.backAudioFileName = nil
        card.createdAt = Date()
        card.updatedAt = Date()
        card.dueAt = Date()
        card.notebook = notebook
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
