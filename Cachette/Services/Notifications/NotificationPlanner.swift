import Foundation
import SwiftData

/// Planification des alertes locales par RÉCONCILIATION : à chaque mutation de
/// stock (et au retour au premier plan), on recalcule tout le plan plutôt que
/// d'empiler des notifications au fil de l'eau.
///
/// - Stock bas : notification immédiate au franchissement du seuil, avec
///   anti-spam (pas de re-notification tant qu'on reste sous le seuil).
/// - Péremption : on ne programme que les ~40 prochaines échéances
///   (limite système : 64 notifications en attente par app).
/// - Ton doux, jamais anxiogène ni culpabilisant (garde-fou du brief).
final class NotificationPlanner {
    static let prefixeStockBas = "stockbas-"
    static let prefixePeremption = "peremption-"
    static let maxPeremptionsProgrammees = 40

    private let centre: any CentreNotifications
    private let defaults: UserDefaults
    private let cleProduitsSignales = "alertes.produitsSignales"
    private let cleLotsSignales = "alertes.lotsSignales"

    init(centre: any CentreNotifications = CentreNotificationsSysteme(), defaults: UserDefaults = .standard) {
        self.centre = centre
        self.defaults = defaults
    }

    /// Recalcule l'intégralité du plan d'alertes à partir de l'état du stock.
    func reconcilier(
        produits: [Produit],
        fenetrePeremptionJours: Int,
        maintenant: Date = .now
    ) async {
        await reconcilierStockBas(produits: produits, maintenant: maintenant)
        await reconcilierPeremptions(
            produits: produits,
            fenetreJours: fenetrePeremptionJours,
            maintenant: maintenant
        )
    }

    // MARK: - Stock bas

    private func reconcilierStockBas(produits: [Produit], maintenant: Date) async {
        var signales = ensemble(pour: cleProduitsSignales)
        let idsActuels = Set(produits.map { $0.id.uuidString })
        signales.formIntersection(idsActuels) // oublie les produits supprimés

        for produit in produits {
            guard let seuil = produit.seuilStockBas else { continue }
            let id = produit.id.uuidString

            if produit.stockTotal <= seuil {
                guard !signales.contains(id) else { continue } // anti-spam
                signales.insert(id)
                await centre.ajouter(
                    id: Self.prefixeStockBas + id,
                    titre: "🐿️ Une cachette se vide",
                    corps: "\(produit.nom) : il en reste \(produit.stockTotal). Pense à réapprovisionner quand tu peux.",
                    date: nil
                )
            } else {
                signales.remove(id) // stock remonté : on réarme l'alerte
            }
        }
        enregistrer(signales, pour: cleProduitsSignales)
    }

    // MARK: - Péremptions

    private func reconcilierPeremptions(
        produits: [Produit],
        fenetreJours: Int,
        maintenant: Date
    ) async {
        let calendrier = Calendar.current
        var lotsSignales = ensemble(pour: cleLotsSignales)

        struct Echeance {
            let lotID: String
            let dateAlerte: Date
            let titre: String
            let corps: String
        }

        var immediates: [Echeance] = []
        var futures: [Echeance] = []
        var lotsExistants = Set<String>()

        for produit in produits {
            for lot in produit.lots {
                guard let peremption = lot.datePeremption, lot.quantite > 0 else { continue }
                let lotID = lot.id.uuidString
                lotsExistants.insert(lotID)

                guard peremption >= maintenant else { continue } // déjà périmé : visible dans l'app
                guard var dateAlerte = calendrier.date(byAdding: .day, value: -fenetreJours, to: peremption)
                else { continue }
                // Alerte à 9 h, heure locale.
                dateAlerte = calendrier.date(bySettingHour: 9, minute: 0, second: 0, of: dateAlerte) ?? dateAlerte

                let echeance = Echeance(
                    lotID: lotID,
                    dateAlerte: dateAlerte,
                    titre: "🐿️ À utiliser bientôt",
                    corps: "\(produit.nom) (\(lot.quantite) unité·s) périme le \(peremption.formatted(date: .abbreviated, time: .omitted)). Autant l'utiliser en premier."
                )

                if dateAlerte <= maintenant {
                    if !lotsSignales.contains(lotID) {
                        immediates.append(echeance)
                        lotsSignales.insert(lotID)
                    }
                } else {
                    futures.append(echeance)
                }
            }
        }

        lotsSignales.formIntersection(lotsExistants)
        enregistrer(lotsSignales, pour: cleLotsSignales)

        for echeance in immediates {
            await centre.ajouter(
                id: Self.prefixePeremption + echeance.lotID,
                titre: echeance.titre,
                corps: echeance.corps,
                date: nil
            )
        }

        // Remplacement complet du plan futur : on retire les obsolètes puis on
        // (re)programme les N prochaines échéances — idempotent.
        let plan = futures
            .sorted { $0.dateAlerte < $1.dateAlerte }
            .prefix(Self.maxPeremptionsProgrammees)
        let idsPlan = Set(plan.map { Self.prefixePeremption + $0.lotID })

        let enAttente = await centre.idsEnAttente()
            .filter { $0.hasPrefix(Self.prefixePeremption) }
        let obsoletes = enAttente.filter { !idsPlan.contains($0) }
        if !obsoletes.isEmpty {
            await centre.retirerEnAttente(ids: obsoletes)
        }

        for echeance in plan {
            await centre.ajouter(
                id: Self.prefixePeremption + echeance.lotID,
                titre: echeance.titre,
                corps: echeance.corps,
                date: echeance.dateAlerte
            )
        }
    }

    // MARK: - Mémoire anti-spam

    private func ensemble(pour cle: String) -> Set<String> {
        Set(defaults.stringArray(forKey: cle) ?? [])
    }

    private func enregistrer(_ ensemble: Set<String>, pour cle: String) {
        defaults.set(Array(ensemble), forKey: cle)
    }
}
