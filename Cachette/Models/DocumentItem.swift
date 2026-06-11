import Foundation
import SwiftData

nonisolated enum TypeDocument: String, Codable, CaseIterable, Identifiable {
    case ordonnance
    case compteRendu
    case autre

    var id: String { rawValue }

    var libelle: String {
        switch self {
        case .ordonnance: "Ordonnance"
        case .compteRendu: "Compte-rendu"
        case .autre: "Autre"
        }
    }
}

/// Métadonnées d'un document du coffre. Le binaire (image/PDF) n'est PAS stocké
/// en base : il vit sur disque, chiffré (Data Protection), géré par `VaultFileStore`.
@Model
final class DocumentItem {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var titre: String
    var date: Date
    /// Fin de validité d'une ordonnance (rappel de renouvellement, P2).
    var dateValidite: Date?
    /// Nom du fichier chiffré dans le coffre (UUID.ext).
    var nomFichier: String
    var mimeType: String

    @Relationship(deleteRule: .nullify, inverse: \Produit.documents)
    var produitsLies: [Produit] = []

    var type: TypeDocument {
        get { TypeDocument(rawValue: typeRaw) ?? .autre }
        set { typeRaw = newValue.rawValue }
    }

    init(
        type: TypeDocument,
        titre: String,
        date: Date = .now,
        dateValidite: Date? = nil,
        nomFichier: String,
        mimeType: String
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.titre = titre
        self.date = date
        self.dateValidite = dateValidite
        self.nomFichier = nomFichier
        self.mimeType = mimeType
    }
}
