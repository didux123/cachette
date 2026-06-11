import Foundation
import SwiftData
import Testing
@testable import Cachette

/// Contexte de test : un container in-memory avec lieux seedés et un service prêt.
@MainActor
struct BancEssai {
    /// Référence forte obligatoire : le ModelContext ne retient pas son container,
    /// le laisser mourir fait crasher SwiftData au premier accès.
    let container: ModelContainer
    let contexte: ModelContext
    let stock: StockService
    let transfert: TransfertService
    let chezMoi: Lieu
    let surMoi: Lieu

    init() throws {
        container = ModelContainerFactory.inMemory()
        contexte = container.mainContext
        try SeedService.seedSiNecessaire(contexte: contexte)
        stock = StockService(contexte: contexte)
        transfert = TransfertService(contexte: contexte)
        let lieux = try contexte.fetch(FetchDescriptor<Lieu>(sortBy: [SortDescriptor(\.ordre)]))
        chezMoi = lieux[0]
        surMoi = lieux[1]
    }

    func mouvements() throws -> [Mouvement] {
        try contexte.fetch(FetchDescriptor<Mouvement>(sortBy: [SortDescriptor(\.date)]))
    }
}

struct StockServiceTests {
    /// Critère P0-2 de la fiche : « Given un produit à 3 unités sur Chez moi,
    /// When je fais −1, Then le stock affiche 2 immédiatement et l'historique
    /// enregistre le mouvement. »
    @Test func criterePO2_moinsUnMetAJourStockEtHistorique() throws {
        let banc = try BancEssai()
        let stylo = try banc.stock.creerProduit(nom: "Stylo insuline", type: .insuline)
        try banc.stock.ajouterStock(produit: stylo, lieu: banc.chezMoi, quantite: 3)

        try banc.stock.retirerStock(produit: stylo, lieu: banc.chezMoi, quantite: 1)

        #expect(stylo.stock(dans: banc.chezMoi) == 2)
        let usages = try banc.mouvements().filter { $0.motif == .usage }
        #expect(usages.count == 1)
        #expect(usages.first?.delta == -1)
    }

    @Test func retirerPlusQueLeStockEstRefuse() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Bandelettes", type: .bandelette)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 2)

        #expect(throws: StockServiceError.stockInsuffisant(disponible: 2)) {
            try banc.stock.retirerStock(produit: produit, lieu: banc.chezMoi, quantite: 5)
        }
        #expect(produit.stock(dans: banc.chezMoi) == 2)
    }

    @Test func ajouterFusionneLesLotsIdentiques() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Cathéters", type: .catheter)
        let peremption = Calendar.current.date(byAdding: .month, value: 6, to: .now)

        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 5, datePeremption: peremption, numeroLot: "A1")
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 3, datePeremption: peremption, numeroLot: "A1")

        #expect(produit.lots.count == 1)
        #expect(produit.stockTotal == 8)
    }

    @Test func leRetraitConsommeDAbordCeQuiPerimeLePlusTot() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Insuline", type: .insuline)
        let calendrier = Calendar.current
        let bientot = calendrier.date(byAdding: .day, value: 20, to: .now)
        let plusTard = calendrier.date(byAdding: .month, value: 8, to: .now)

        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 4, datePeremption: plusTard, numeroLot: "TARD")
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 2, datePeremption: bientot, numeroLot: "TOT")

        try banc.stock.retirerStock(produit: produit, lieu: banc.chezMoi, quantite: 3)

        // Les 2 du lot qui périme bientôt sont partis en premier (FEFO), puis 1 de l'autre.
        #expect(produit.stock(dans: banc.chezMoi) == 3)
        #expect(produit.lots.allSatisfy { $0.numeroLot == "TARD" })
    }

    @Test func unLotVideEstSupprime() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Compresses", type: .autre)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 2)

        try banc.stock.retirerStock(produit: produit, lieu: banc.chezMoi, quantite: 2)

        #expect(produit.lots.isEmpty)
        #expect(produit.stockTotal == 0)
    }

    @Test func leStockTotalSommeTousLesLieux() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Stylos", type: .seringue)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 7)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.surMoi, quantite: 3)

        #expect(produit.stockTotal == 10)
        #expect(produit.stock(dans: banc.chezMoi) == 7)
        #expect(produit.stock(dans: banc.surMoi) == 3)
    }
}

struct TransfertServiceTests {
    /// Critère P0-2b de la fiche : « Given 10 stylos sur Chez mes parents,
    /// When je pars avec 3 sur moi, Then Chez mes parents affiche 7 et
    /// Sur moi affiche 3, et l'historique montre le transfert. »
    @Test func criterePO2b_jeParsAvecTroisStylos() throws {
        let banc = try BancEssai()
        let parents = try banc.stock.creerLieu(nom: "Chez mes parents", type: .parents)
        let stylos = try banc.stock.creerProduit(nom: "Stylos insuline", type: .insuline)
        try banc.stock.ajouterStock(produit: stylos, lieu: parents, quantite: 10)

        try banc.transfert.transferer(produit: stylos, de: parents, vers: banc.surMoi, quantite: 3)

        #expect(stylos.stock(dans: parents) == 7)
        #expect(stylos.stock(dans: banc.surMoi) == 3)

        let mouvements = try banc.mouvements().filter { $0.transfertID != nil }
        #expect(mouvements.count == 2)
        #expect(mouvements.map(\.delta).sorted() == [-3, 3])
        // Les deux mouvements sont liés par le même identifiant de transfert.
        #expect(Set(mouvements.compactMap(\.transfertID)).count == 1)
    }

    @Test func laPeremptionSuitLesUnitesTransferees() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Insuline", type: .insuline)
        let peremption = Calendar.current.date(byAdding: .month, value: 3, to: .now)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 5, datePeremption: peremption, numeroLot: "L42")

        try banc.transfert.transferer(produit: produit, de: banc.chezMoi, vers: banc.surMoi, quantite: 2)

        let lotDestination = try #require(produit.lots.first { $0.lieu?.id == banc.surMoi.id })
        #expect(lotDestination.datePeremption == peremption)
        #expect(lotDestination.numeroLot == "L42")
        #expect(produit.stock(dans: banc.chezMoi) == 3)
    }

    @Test func transfererVersLeMemeLieuEstRefuse() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Test", type: .autre)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 5)

        #expect(throws: TransfertError.memeLieu) {
            try banc.transfert.transferer(produit: produit, de: banc.chezMoi, vers: banc.chezMoi, quantite: 1)
        }
    }

    @Test func transfererPlusQueLeDisponibleEstRefuseSansRienChanger() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Test", type: .autre)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 2)

        #expect(throws: StockServiceError.stockInsuffisant(disponible: 2)) {
            try banc.transfert.transferer(produit: produit, de: banc.chezMoi, vers: banc.surMoi, quantite: 9)
        }
        #expect(produit.stock(dans: banc.chezMoi) == 2)
        #expect(produit.stock(dans: banc.surMoi) == 0)
        let mouvementsTransfert = try banc.mouvements().filter { $0.transfertID != nil }
        #expect(mouvementsTransfert.isEmpty)
    }

    @Test func leTransfertTraverseLesLotsEnFEFO() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Capteurs", type: .bandelette)
        let calendrier = Calendar.current
        let tot = calendrier.date(byAdding: .day, value: 15, to: .now)
        let tard = calendrier.date(byAdding: .month, value: 9, to: .now)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 2, datePeremption: tot, numeroLot: "TOT")
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 4, datePeremption: tard, numeroLot: "TARD")

        try banc.transfert.transferer(produit: produit, de: banc.chezMoi, vers: banc.surMoi, quantite: 3)

        // 2 unités TOT + 1 unité TARD sont parties → deux lots distincts à destination.
        let lotsDestination = produit.lots.filter { $0.lieu?.id == banc.surMoi.id }
        #expect(lotsDestination.count == 2)
        #expect(lotsDestination.first { $0.numeroLot == "TOT" }?.quantite == 2)
        #expect(lotsDestination.first { $0.numeroLot == "TARD" }?.quantite == 1)
        #expect(produit.stock(dans: banc.chezMoi) == 3)
    }
}
