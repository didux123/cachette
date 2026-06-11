import Foundation
import SwiftData

extension Notification.Name {
    /// Émis par les services après chaque mutation de stock — déclenche la
    /// réconciliation des alertes.
    static let cachetteStockMute = Notification.Name("cachetteStockMute")
}

enum ReglagesCles {
    static let fenetrePeremptionJours = "fenetrePeremptionJours"
    static let fenetrePeremptionDefaut = 30
    static let notificationsActivees = "notificationsActivees"
}

enum Alertes {
    /// Recalcule le plan d'alertes depuis l'état courant du stock.
    static func reconcilier(contexte: ModelContext) async {
        let produits = (try? contexte.fetch(FetchDescriptor<Produit>())) ?? []
        let fenetre = UserDefaults.standard.object(forKey: ReglagesCles.fenetrePeremptionJours) as? Int
            ?? ReglagesCles.fenetrePeremptionDefaut
        await NotificationPlanner().reconcilier(
            produits: produits,
            fenetrePeremptionJours: fenetre
        )
    }
}
