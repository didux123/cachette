import Foundation
import Testing
@testable import Cachette

struct MascotteEngineTests {
    @Test func sereineSansProduits() throws {
        #expect(MascotteEngine.etat(produits: [], fenetrePeremptionJours: 30) == .sereine)
    }

    @Test func sereineQuandToutVaBien() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Stylos", type: .insuline, seuilStockBas: 3)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 20)

        #expect(MascotteEngine.etat(produits: [produit], fenetrePeremptionJours: 30) == .sereine)
    }

    @Test func vigilanteQuandLeStockApprocheDuSeuil() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Stylos", type: .insuline, seuilStockBas: 3)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 5) // seuil+2

        #expect(MascotteEngine.etat(produits: [produit], fenetrePeremptionJours: 30) == .vigilante)
    }

    @Test func alerteQuandLeStockEstSousLeSeuil() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Stylos", type: .insuline, seuilStockBas: 3)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 2)

        #expect(MascotteEngine.etat(produits: [produit], fenetrePeremptionJours: 30) == .alerte)
    }

    @Test func vigilanteQuandUnLotPerimeBientot() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Insuline", type: .insuline)
        let bientot = Calendar.current.date(byAdding: .day, value: 12, to: .now)!
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 4, datePeremption: bientot)

        #expect(MascotteEngine.etat(produits: [produit], fenetrePeremptionJours: 30) == .vigilante)
    }

    @Test func alerteQuandUnLotEstPerime() throws {
        let banc = try BancEssai()
        let produit = try banc.stock.creerProduit(nom: "Insuline", type: .insuline)
        let passe = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 4, datePeremption: passe)

        #expect(MascotteEngine.etat(produits: [produit], fenetrePeremptionJours: 30) == .alerte)
    }

    @Test func lAlerteGagneSurLaVigilance() throws {
        let banc = try BancEssai()
        let ok = try banc.stock.creerProduit(nom: "Compresses", type: .autre, seuilStockBas: 3)
        try banc.stock.ajouterStock(produit: ok, lieu: banc.chezMoi, quantite: 4) // vigilance
        let vide = try banc.stock.creerProduit(nom: "Stylos", type: .insuline, seuilStockBas: 5)
        try banc.stock.ajouterStock(produit: vide, lieu: banc.chezMoi, quantite: 1) // alerte

        #expect(MascotteEngine.etat(produits: [ok, vide], fenetrePeremptionJours: 30) == .alerte)
    }
}
