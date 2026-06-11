import Foundation

/// Estimation des besoins pour un séjour (P1-3, « Mode Je pars ») :
/// à partir du journal des Mouvements d'usage, on estime la consommation
/// journalière et ce qu'il faut emporter, compte tenu du stock sur place.
///
/// Règle d'or : sans historique d'usage, PAS d'estimation (`besoin == nil`) —
/// on ne montre jamais un faux chiffre.
nonisolated struct EstimationProduit: Identifiable {
    let id: UUID
    let nomProduit: String
    /// Consommation moyenne par jour (nil = pas assez d'historique).
    let tauxJournalier: Double?
    /// Unités nécessaires pour le séjour, marge incluse, arrondies au
    /// conditionnement (nil = estimation impossible).
    let besoin: Int?
    /// Stock déjà présent au lieu de destination.
    let stockDestination: Int
    /// Ce qu'il faut emporter : max(0, besoin − sur place). nil si pas d'estimation.
    var aEmporter: Int? {
        besoin.map { max(0, $0 - stockDestination) }
    }
}

nonisolated enum TripEstimator {
    /// Fenêtre d'observation de la consommation.
    static let fenetreJours = 60

    static func estimer(
        produits: [(produit: ProduitSnapshot, mouvementsUsage: [(delta: Int, date: Date)])],
        dureeJours: Int,
        marge: Double = 1.2,
        maintenant: Date = .now
    ) -> [EstimationProduit] {
        produits.map { entree in
            let taux = tauxJournalier(
                mouvementsUsage: entree.mouvementsUsage,
                maintenant: maintenant
            )
            let besoin = taux.map { taux in
                arrondiAuConditionnement(
                    Int(ceil(taux * Double(dureeJours) * marge)),
                    conditionnement: entree.produit.conditionnement
                )
            }
            return EstimationProduit(
                id: entree.produit.id,
                nomProduit: entree.produit.nom,
                tauxJournalier: taux,
                besoin: besoin,
                stockDestination: entree.produit.stockDestination
            )
        }
    }

    /// Moyenne d'usage par jour sur la fenêtre, calée sur le premier usage
    /// observé (un produit suivi depuis 10 jours n'est pas moyenné sur 60).
    static func tauxJournalier(
        mouvementsUsage: [(delta: Int, date: Date)],
        maintenant: Date = .now
    ) -> Double? {
        let calendrier = Calendar.current
        guard let debutFenetre = calendrier.date(byAdding: .day, value: -fenetreJours, to: maintenant)
        else { return nil }

        let dansFenetre = mouvementsUsage.filter { $0.date >= debutFenetre && $0.date <= maintenant }
        guard let premierUsage = dansFenetre.map(\.date).min() else { return nil }

        let totalUtilise = dansFenetre.reduce(0) { $0 + abs($1.delta) }
        guard totalUtilise > 0 else { return nil }

        let joursObserves = max(
            1,
            calendrier.dateComponents([.day], from: premierUsage, to: maintenant).day ?? 1
        )
        return Double(totalUtilise) / Double(joursObserves)
    }

    /// Arrondit au multiple de conditionnement supérieur (on emporte des
    /// boîtes entières), sans jamais descendre sous le besoin brut.
    static func arrondiAuConditionnement(_ besoin: Int, conditionnement: Int) -> Int {
        guard conditionnement > 1, besoin > 0 else { return besoin }
        let boites = Int(ceil(Double(besoin) / Double(conditionnement)))
        return boites * conditionnement
    }
}

/// Photo minimale d'un produit pour l'estimateur — découple la logique pure
/// des objets SwiftData.
nonisolated struct ProduitSnapshot {
    let id: UUID
    let nom: String
    let conditionnement: Int
    let stockDestination: Int
}
