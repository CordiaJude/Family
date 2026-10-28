import Foundation
import SwiftData

public enum FamilySchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Household.self, Member.self,
            Event.self, EventException.self, RideClaim.self, BusyBlock.self,
            FamilyList.self, ListItem.self,
            Chore.self, ChoreCompletion.self, AllowanceEntry.self,
            MealPlanEntry.self, BoardNote.self,
            Place.self, PlaceAlert.self, LocationSnapshot.self, ArriveSafelySession.self,
        ]
    }
}

public enum FamilyMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [FamilySchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

/// Creates the household store.
///
/// The store lives in the App Group container so the widget and share
/// extensions read the same data. CloudKit mirroring is off: sync is done by
/// SyncService with CKSyncEngine, which supports the shared database.
public enum FamilyStore {
    /// Info.plist key holding the App Group identifier (set from Signing.xcconfig).
    public static let appGroupInfoKey = "FamilyAppGroupIdentifier"

    public static var appGroupIdentifier: String? {
        Bundle.main.object(forInfoDictionaryKey: appGroupInfoKey) as? String
    }

    public static var schema: Schema { Schema(versionedSchema: FamilySchemaV1.self) }

    /// Directory shared between the app and its extensions, falling back to
    /// Application Support when the App Group isn't provisioned (unsigned
    /// Simulator builds).
    public static func sharedDirectory() -> URL {
        if let group = appGroupIdentifier,
           let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
            return url.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        }
        return URL.applicationSupportDirectory
    }

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            let directory = sharedDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            configuration = ModelConfiguration(
                schema: schema,
                url: directory.appending(path: "Family.store"),
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(for: schema, migrationPlan: FamilyMigrationPlan.self, configurations: [configuration])
    }
}
