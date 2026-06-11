import Foundation

/// Dérive l'état de la mascotte de l'état réel des réserves (brief §5).
/// Pur et synchrone → testable.
nonisolated enum MascotteEngine {
    /// - alerte : un produit est sous (ou à) son seuil, ou un lot est périmé ;
    /// - vigilante : un produit approche de son seuil (≤ seuil + 2) ou un lot
    ///   périme dans la fenêtre configurée ;
    /// - sereine sinon.
    static func etat(
        produits: [Produit],
        fenetrePeremptionJours: Int,
        maintenant: Date = .now
    ) -> MascotteState {
        var vigilance = false

        for produit in produits {
            // Niveau de stock vs seuil.
            if let seuil = produit.seuilStockBas {
                let stock = produit.stockTotal
                if stock <= seuil { return .alerte }
                if stock <= seuil + 2 { vigilance = true }
            }
            // Péremptions.
            for lot in produit.lots where lot.quantite > 0 {
                guard let peremption = lot.datePeremption else { continue }
                if peremption < maintenant { return .alerte }
                if lot.perimeAvant(jours: fenetrePeremptionJours, depuis: maintenant) {
                    vigilance = true
                }
            }
        }

        return vigilance ? .vigilante : .sereine
    }
}
