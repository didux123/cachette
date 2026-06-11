import Foundation
import SwiftData
import Testing
@testable import Cachette

/// Centre de notifications factice : enregistre les appels au lieu de notifier.
@MainActor
final class CentreFake: CentreNotifications {
    struct Ajout: Equatable {
        let id: String
        let corps: String
        let date: Date?
    }

    private(set) var ajouts: [Ajout] = []
    private(set) var retraits: [String] = []
    private var enAttente: Set<String> = []

    func demanderAutorisation() async -> Bool { true }

    func ajouter(id: String, titre: String, corps: String, date: Date?) async {
        ajouts.append(Ajout(id: id, corps: corps, date: date))
        if date != nil { enAttente.insert(id) }
    }

    func retirerEnAttente(ids: [String]) async {
        retraits.append(contentsOf: ids)
        enAttente.subtract(ids)
    }

    func idsEnAttente() async -> [String] { Array(enAttente) }

    var immediates: [Ajout] { ajouts.filter { $0.date == nil } }
    var programmees: [Ajout] { ajouts.filter { $0.date != nil } }
}

@MainActor
private func planner(_ centre: CentreFake) -> NotificationPlanner {
    NotificationPlanner(centre: centre, defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
}

struct NotificationPlannerStockBasTests {
    @Test func notifieAuFranchissementDuSeuilUneSeuleFois() async throws {
        let banc = try BancEssai()
        let centre = CentreFake()
        let plan = planner(centre)
        let produit = try banc.stock.creerProduit(nom: "Capteurs", type: .bandelette, seuilStockBas: 5)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 4)

        await plan.reconcilier(produits: [produit], fenetrePeremptionJours: 30)
        await plan.reconcilier(produits: [produit], fenetrePeremptionJours: 30)

        #expect(centre.immediates.count == 1)
        #expect(centre.immediates.first?.id == NotificationPlanner.prefixeStockBas + produit.id.uuidString)
        #expect(centre.immediates.first?.corps.contains("Capteurs") == true)
    }

    @Test func pasDeNotificationAuDessusDuSeuil() async throws {
        let banc = try BancEssai()
        let centre = CentreFake()
        let plan = planner(centre)
        let produit = try banc.stock.creerProduit(nom: "Stylos", type: .insuline, seuilStockBas: 3)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 10)

        await plan.reconcilier(produits: [produit], fenetrePeremptionJours: 30)

        #expect(centre.ajouts.isEmpty)
    }

    @Test func reArmeQuandLeStockRemonte() async throws {
        let banc = try BancEssai()
        let centre = CentreFake()
        let plan = planner(centre)
        let produit = try banc.stock.creerProduit(nom: "Stylos", type: .insuline, seuilStockBas: 3)
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 2)

        await plan.reconcilier(produits: [produit], fenetrePeremptionJours: 30) // 1re alerte
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 10) // réassort
        await plan.reconcilier(produits: [produit], fenetrePeremptionJours: 30) // ré-arme
        try banc.stock.retirerStock(produit: produit, lieu: banc.chezMoi, quantite: 10) // re-chute
        await plan.reconcilier(produits: [produit], fenetrePeremptionJours: 30) // 2e alerte

        #expect(centre.immediates.count == 2)
    }
}

struct NotificationPlannerPeremptionTests {
    @Test func peremptionLointaineEstProgrammee() async throws {
        let banc = try BancEssai()
        let centre = CentreFake()
        let plan = planner(centre)
        let calendrier = Calendar.current
        let produit = try banc.stock.creerProduit(nom: "Insuline", type: .insuline)
        let peremption = calendrier.date(byAdding: .day, value: 90, to: .now)!
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 3, datePeremption: peremption)

        await plan.reconcilier(produits: [produit], fenetrePeremptionJours: 30)

        #expect(centre.programmees.count == 1)
        let ajout = try #require(centre.programmees.first)
        #expect(ajout.id.hasPrefix(NotificationPlanner.prefixePeremption))
        // Alerte ~60 jours avant aujourd'hui + 90 = à J+60, à 9 h.
        let attendue = calendrier.date(byAdding: .day, value: -30, to: peremption)!
        let delta = abs(ajout.date!.timeIntervalSince(attendue))
        #expect(delta < 24 * 3600)
    }

    @Test func peremptionDansLaFenetreNotifieImmediatementUneFois() async throws {
        let banc = try BancEssai()
        let centre = CentreFake()
        let plan = planner(centre)
        let produit = try banc.stock.creerProduit(nom: "Insuline", type: .insuline)
        let peremption = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 3, datePeremption: peremption)

        await plan.reconcilier(produits: [produit], fenetrePeremptionJours: 30)
        await plan.reconcilier(produits: [produit], fenetrePeremptionJours: 30)

        #expect(centre.immediates.count == 1)
        #expect(centre.immediates.first?.corps.contains("Insuline") == true)
    }

    @Test func lotPerimeNEstPasNotifie() async throws {
        let banc = try BancEssai()
        let centre = CentreFake()
        let plan = planner(centre)
        let produit = try banc.stock.creerProduit(nom: "Vieux truc", type: .autre)
        let passe = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 1, datePeremption: passe)

        await plan.reconcilier(produits: [produit], fenetrePeremptionJours: 30)

        #expect(centre.ajouts.isEmpty)
    }

    @Test func leNombreDEcheancesProgrammeesEstPlafonne() async throws {
        let banc = try BancEssai()
        let centre = CentreFake()
        let plan = planner(centre)
        let calendrier = Calendar.current
        let produit = try banc.stock.creerProduit(nom: "Multi-lots", type: .medicament)
        for jours in 0..<50 {
            let peremption = calendrier.date(byAdding: .day, value: 60 + jours, to: .now)!
            try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 1, datePeremption: peremption)
        }

        await plan.reconcilier(produits: [produit], fenetrePeremptionJours: 30)

        #expect(centre.programmees.count == NotificationPlanner.maxPeremptionsProgrammees)
    }

    @Test func uneEcheanceObsoleteEstRetiree() async throws {
        let banc = try BancEssai()
        let centre = CentreFake()
        let plan = planner(centre)
        let produit = try banc.stock.creerProduit(nom: "Insuline", type: .insuline)
        let peremption = Calendar.current.date(byAdding: .day, value: 90, to: .now)!
        try banc.stock.ajouterStock(produit: produit, lieu: banc.chezMoi, quantite: 3, datePeremption: peremption)

        await plan.reconcilier(produits: [produit], fenetrePeremptionJours: 30)
        let idProgramme = try #require(centre.programmees.first?.id)

        // Le lot est consommé : son échéance doit disparaître du plan.
        try banc.stock.retirerStock(produit: produit, lieu: banc.chezMoi, quantite: 3)
        await plan.reconcilier(produits: [produit], fenetrePeremptionJours: 30)

        #expect(centre.retraits.contains(idProgramme))
    }
}
