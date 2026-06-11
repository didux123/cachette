import Foundation
import SwiftData

/// Schéma versionné dès la V1 : toute évolution future passe par une SchemaV2
/// + un stage de migration, jamais par une modification sauvage des modèles.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Lieu.self, Produit.self, Lot.self, Mouvement.self, DocumentItem.self]
    }
}

enum CachetteMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
