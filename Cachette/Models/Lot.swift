import Foundation
import SwiftData

/// Ligne de stock : une quantité d'un produit, dans un lieu, avec une péremption optionnelle.
/// La quantité courante vit ici ; les `Mouvement` sont le journal, on ne recalcule
/// jamais le stock depuis l'historique.
@Model
final class Lot {
    @Attribute(.unique) var id: UUID
    var quantite: Int
    var datePeremption: Date?
    /// Numéro de lot fabricant (AI 10 du Datamatrix GS1).
    var numeroLot: String?
    var dateAjout: Date

    var produit: Produit?
    var lieu: Lieu?

    var estPerime: Bool {
        guard let datePeremption else { return false }
        return datePeremption < .now
    }

    func perimeAvant(jours: Int, depuis date: Date = .now) -> Bool {
        guard let datePeremption else { return false }
        let limite = Calendar.current.date(byAdding: .day, value: jours, to: date) ?? date
        return datePeremption <= limite
    }

    init(
        produit: Produit?,
        lieu: Lieu?,
        quantite: Int,
        datePeremption: Date? = nil,
        numeroLot: String? = nil
    ) {
        self.id = UUID()
        self.quantite = quantite
        self.datePeremption = datePeremption
        self.numeroLot = numeroLot
        self.dateAjout = .now
        self.produit = produit
        self.lieu = lieu
    }
}
