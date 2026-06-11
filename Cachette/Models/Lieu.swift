import Foundation
import SwiftData

nonisolated enum TypeLieu: String, Codable, CaseIterable, Identifiable {
    case domicile
    case parents
    case travail
    case surMoi
    case autre

    var id: String { rawValue }

    var libelle: String {
        switch self {
        case .domicile: "Domicile"
        case .parents: "Parents"
        case .travail: "Travail"
        case .surMoi: "Sur moi"
        case .autre: "Autre"
        }
    }

    var emojiParDefaut: String {
        switch self {
        case .domicile: "🏠"
        case .parents: "👨‍👩‍👧"
        case .travail: "💼"
        case .surMoi: "🎒"
        case .autre: "📦"
        }
    }
}

@Model
final class Lieu {
    @Attribute(.unique) var id: UUID
    var nom: String
    var typeRaw: String
    var emoji: String
    var couleurHex: String
    /// Lieu spécial « Sur moi » : présent par défaut, non supprimable (P0-1).
    var estSurMoi: Bool
    var ordre: Int
    var dateCreation: Date

    @Relationship(deleteRule: .cascade, inverse: \Lot.lieu)
    var lots: [Lot] = []

    @Relationship(deleteRule: .nullify, inverse: \Mouvement.lieu)
    var mouvements: [Mouvement] = []

    var type: TypeLieu {
        get { TypeLieu(rawValue: typeRaw) ?? .autre }
        set { typeRaw = newValue.rawValue }
    }

    init(
        nom: String,
        type: TypeLieu = .autre,
        emoji: String? = nil,
        couleurHex: String = "C8643C",
        estSurMoi: Bool = false,
        ordre: Int = 0
    ) {
        self.id = UUID()
        self.nom = nom
        self.typeRaw = type.rawValue
        self.emoji = emoji ?? type.emojiParDefaut
        self.couleurHex = couleurHex
        self.estSurMoi = estSurMoi
        self.ordre = ordre
        self.dateCreation = .now
    }
}
