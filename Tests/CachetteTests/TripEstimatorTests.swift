import Foundation
import Testing
@testable import Cachette

struct TripEstimatorTests {
    private let calendrier = Calendar.current
    private let maintenant = Date.now

    private func ilYA(_ jours: Int) -> Date {
        calendrier.date(byAdding: .day, value: -jours, to: maintenant)!
    }

    @Test func historiqueRicheDonneUneEstimation() {
        // 2 unités il y a 10 j + 1 unité il y a 5 j = 3 unités sur 10 jours observés.
        let usage: [(delta: Int, date: Date)] = [(-2, ilYA(10)), (-1, ilYA(5))]
        let snapshot = ProduitSnapshot(id: UUID(), nom: "Stylos", conditionnement: 1, stockDestination: 1)

        let estimations = TripEstimator.estimer(
            produits: [(snapshot, usage)],
            dureeJours: 7,
            marge: 1.2,
            maintenant: maintenant
        )

        let estimation = estimations[0]
        #expect(estimation.tauxJournalier == 0.3)
        // ceil(0.3 × 7 × 1.2) = ceil(2.52) = 3 ; sur place 1 → emporter 2.
        #expect(estimation.besoin == 3)
        #expect(estimation.aEmporter == 2)
    }

    @Test func sansHistoriquePasDeFauxChiffre() {
        let snapshot = ProduitSnapshot(id: UUID(), nom: "Nouveau", conditionnement: 1, stockDestination: 0)

        let estimations = TripEstimator.estimer(
            produits: [(snapshot, [])],
            dureeJours: 7,
            maintenant: maintenant
        )

        #expect(estimations[0].tauxJournalier == nil)
        #expect(estimations[0].besoin == nil)
        #expect(estimations[0].aEmporter == nil)
    }

    @Test func lesUsagesHorsFenetreSontIgnores() {
        let usage: [(delta: Int, date: Date)] = [(-10, ilYA(90))] // trop vieux
        #expect(TripEstimator.tauxJournalier(mouvementsUsage: usage, maintenant: maintenant) == nil)
    }

    @Test func leBesoinEstArrondiAuConditionnement() {
        // Besoin brut 3, boîtes de 5 → on emporte une boîte entière de 5.
        let usage: [(delta: Int, date: Date)] = [(-2, ilYA(10)), (-1, ilYA(5))]
        let snapshot = ProduitSnapshot(id: UUID(), nom: "Gélules", conditionnement: 5, stockDestination: 0)

        let estimations = TripEstimator.estimer(
            produits: [(snapshot, usage)],
            dureeJours: 7,
            marge: 1.2,
            maintenant: maintenant
        )

        #expect(estimations[0].besoin == 5)
    }

    @Test func leStockSurPlaceSuffitRienAEmporter() {
        let usage: [(delta: Int, date: Date)] = [(-1, ilYA(10))]
        let snapshot = ProduitSnapshot(id: UUID(), nom: "Compresses", conditionnement: 1, stockDestination: 50)

        let estimations = TripEstimator.estimer(
            produits: [(snapshot, usage)],
            dureeJours: 7,
            maintenant: maintenant
        )

        #expect(estimations[0].aEmporter == 0)
    }

    @Test func arrondiConditionnementCasLimites() {
        #expect(TripEstimator.arrondiAuConditionnement(0, conditionnement: 5) == 0)
        #expect(TripEstimator.arrondiAuConditionnement(5, conditionnement: 5) == 5)
        #expect(TripEstimator.arrondiAuConditionnement(6, conditionnement: 5) == 10)
        #expect(TripEstimator.arrondiAuConditionnement(3, conditionnement: 1) == 3)
    }

    @Test func unUsageAujourdHuiCompteSurUnJourMinimum() {
        let usage: [(delta: Int, date: Date)] = [(-4, maintenant)]
        let taux = TripEstimator.tauxJournalier(mouvementsUsage: usage, maintenant: maintenant)
        #expect(taux == 4.0) // 4 unités / max(1 jour)
    }
}
