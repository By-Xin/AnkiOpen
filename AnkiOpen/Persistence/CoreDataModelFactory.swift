import CoreData

enum CoreDataModelFactory {
    static func makeModel() -> NSManagedObjectModel {
        model
    }

    private static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let notebook = entity(name: "Notebook", className: NotebookMO.self)
        notebook.properties = [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("name", .stringAttributeType, optional: false),
            attribute("createdAt", .dateAttributeType, optional: false),
            attribute("updatedAt", .dateAttributeType, optional: false)
        ]

        let flashcard = entity(name: "Flashcard", className: FlashcardMO.self)
        flashcard.properties = [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("front", .stringAttributeType, optional: false),
            attribute("back", .stringAttributeType, optional: false),
            attribute("frontAudioFileName", .stringAttributeType, optional: true),
            attribute("backAudioFileName", .stringAttributeType, optional: true),
            attribute("createdAt", .dateAttributeType, optional: false),
            attribute("updatedAt", .dateAttributeType, optional: false),
            attribute("isArchived", .booleanAttributeType, optional: false, defaultValue: false),
            attribute("dueAt", .dateAttributeType, optional: false),
            attribute("stability", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("difficulty", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("elapsedDays", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("scheduledDays", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("learningSteps", .integer16AttributeType, optional: false, defaultValue: 0),
            attribute("reps", .integer32AttributeType, optional: false, defaultValue: 0),
            attribute("lapses", .integer32AttributeType, optional: false, defaultValue: 0),
            attribute("state", .integer16AttributeType, optional: false, defaultValue: 0),
            attribute("lastReviewAt", .dateAttributeType, optional: true)
        ]

        let reviewLog = entity(name: "ReviewLog", className: ReviewLogMO.self)
        reviewLog.properties = [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("reviewedAt", .dateAttributeType, optional: false),
            attribute("rating", .integer16AttributeType, optional: false),
            attribute("previousDueAt", .dateAttributeType, optional: false),
            attribute("nextDueAt", .dateAttributeType, optional: false)
        ]

        let importBatch = entity(name: "ImportBatch", className: ImportBatchMO.self)
        importBatch.properties = [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("fileName", .stringAttributeType, optional: false),
            attribute("importedAt", .dateAttributeType, optional: false),
            attribute("totalRows", .integer32AttributeType, optional: false, defaultValue: 0),
            attribute("importedRows", .integer32AttributeType, optional: false, defaultValue: 0),
            attribute("skippedRows", .integer32AttributeType, optional: false, defaultValue: 0),
            attribute("errorsSummary", .stringAttributeType, optional: true)
        ]

        let notebookFlashcards = relationship("flashcards", destination: flashcard, toMany: true, deleteRule: .cascadeDeleteRule)
        let flashcardNotebook = relationship("notebook", destination: notebook, toMany: false, deleteRule: .nullifyDeleteRule, optional: false)
        notebookFlashcards.inverseRelationship = flashcardNotebook
        flashcardNotebook.inverseRelationship = notebookFlashcards

        let flashcardReviewLogs = relationship("reviewLogs", destination: reviewLog, toMany: true, deleteRule: .cascadeDeleteRule)
        let reviewLogCard = relationship("card", destination: flashcard, toMany: false, deleteRule: .nullifyDeleteRule, optional: false)
        flashcardReviewLogs.inverseRelationship = reviewLogCard
        reviewLogCard.inverseRelationship = flashcardReviewLogs

        let notebookImportBatches = relationship("importBatches", destination: importBatch, toMany: true, deleteRule: .cascadeDeleteRule)
        let importBatchNotebook = relationship("notebook", destination: notebook, toMany: false, deleteRule: .nullifyDeleteRule, optional: false)
        notebookImportBatches.inverseRelationship = importBatchNotebook
        importBatchNotebook.inverseRelationship = notebookImportBatches

        notebook.properties.append(contentsOf: [notebookFlashcards, notebookImportBatches])
        flashcard.properties.append(contentsOf: [flashcardNotebook, flashcardReviewLogs])
        reviewLog.properties.append(reviewLogCard)
        importBatch.properties.append(importBatchNotebook)

        model.entities = [notebook, flashcard, reviewLog, importBatch]
        return model
    }()

    private static func entity<T: NSManagedObject>(name: String, className: T.Type) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(className)
        return entity
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }

    private static func relationship(
        _ name: String,
        destination: NSEntityDescription,
        toMany: Bool,
        deleteRule: NSDeleteRule,
        optional: Bool = true
    ) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.destinationEntity = destination
        relationship.deleteRule = deleteRule
        relationship.isOptional = optional
        relationship.minCount = optional ? 0 : 1
        relationship.maxCount = toMany ? 0 : 1
        return relationship
    }
}
