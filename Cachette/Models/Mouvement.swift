import Foundation
import SwiftData

nonisolated enum MotifMouvement: String, Codable, CaseIterable {
    case usage
    case reception
    case transfertSortie
    case transfertEntree
    case ajustement
    case peremption

    var libelle: String {
        switch self {
        case .usage: "Utilisé"
        case .reception: "Reçu"
        case .transfertSortie: "Transfert (départ)"
        case .transfertEntree: "Transfert (arrivée)"
        case .ajustement: "Ajustement"
        case .peremption: "Périmé"
        }
    }
}

/// Journal append-only des variations de stock. Prépare la prédiction de
/// consommation (P2) et alimente le Mode « Je pars ».
@Model
final class Mouvement {
    @Attribute(.unique) var id: UUID
    /// Variation signée (+3 reçu, −1 utilisé…).
    var delta: Int
    var date: Date
    var motifRaw: String
    /// Les deux mouvements d'un même transfert (sortie + entrée) partagent cet UUID.
    var transfertID: UUID?
    /// Dénormalisés : l'historique reste lisible même si le lieu/produit est supprimé.
    var produitNom: String
    var lieuNom: String

    var produit: Produit?
    var lieu: Lieu?

    var motif: MotifMouvement {
        get { MotifMouvement(rawValue: motifRaw) ?? .ajustement }
        set { motifRaw = newValue.rawValue }
    }

    init(
        produit: Produit?,
        lieu: Lieu?,
        delta: Int,
        motif: MotifMouvement,
        date: Date = .now,
        transfertID: UUID? = nil
    ) {
        self.id = UUID()
        self.delta = delta
        self.date = date
        self.motifRaw = motif.rawValue
        self.transfertID = transfertID
        self.produitNom = produit?.nom ?? ""
        self.lieuNom = lieu?.nom ?? ""
        self.produit = produit
        self.lieu = lieu
    }
}
