import Foundation
import SwiftData

enum ModelContainerFactory {
    /// Container de production (stockage sur disque, migrations versionnées).
    static func production() -> ModelContainer {
        do {
            return try ModelContainer(
                for: Schema(versionedSchema: SchemaV1.self),
                migrationPlan: CachetteMigrationPlan.self,
                configurations: [ModelConfiguration()]
            )
        } catch {
            fatalError("Impossible de créer le ModelContainer : \(error)")
        }
    }

    /// Container en mémoire pour les tests et les previews.
    static func inMemory() -> ModelContainer {
        do {
            return try ModelContainer(
                for: Schema(versionedSchema: SchemaV1.self),
                migrationPlan: CachetteMigrationPlan.self,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
        } catch {
            fatalError("Impossible de créer le container in-memory : \(error)")
        }
    }
}
