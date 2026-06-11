import Foundation
import SwiftData

enum StockServiceError: LocalizedError, Equatable {
    case lieuSurMoiNonSupprimable
    case quantiteInvalide
    case stockInsuffisant(disponible: Int)

    var errorDescription: String? {
        switch self {
        case .lieuSurMoiNonSupprimable:
            "Le lieu « Sur moi » voyage toujours avec toi — il ne peut pas être supprimé."
        case .quantiteInvalide:
            "La quantité doit être supérieure à zéro."
        case .stockInsuffisant(let disponible):
            "Il ne reste que \(disponible) unité(s) à cet endroit."
        }
    }
}

/// Toutes les mutations de lieux et de stock passent par ici, jamais par les vues.
/// Les invariants métier (lieu « Sur moi » indestructible, cohérence des quantités,
/// journal de Mouvements) sont garantis dans cette couche.
struct StockService {
    let contexte: ModelContext

    /// Sauvegarde puis signale la mutation (déclenche la réconciliation des alertes).
    private func sauvegarder() throws {
        try contexte.save()
        NotificationCenter.default.post(name: .cachetteStockMute, object: nil)
    }

    // MARK: - Lieux

    @discardableResult
    func creerLieu(nom: String, type: TypeLieu, emoji: String? = nil, couleurHex: String = "C8643C") throws -> Lieu {
        let ordreMax = (try? contexte.fetch(FetchDescriptor<Lieu>()))?.map(\.ordre).max() ?? 0
        let lieu = Lieu(nom: nom, type: type, emoji: emoji, couleurHex: couleurHex, ordre: ordreMax + 1)
        contexte.insert(lieu)
        try sauvegarder()
        return lieu
    }

    func renommerLieu(_ lieu: Lieu, nom: String) throws {
        lieu.nom = nom
        try sauvegarder()
    }

    /// Refuse la suppression du lieu spécial « Sur moi » (P0-1) — garde-fou
    /// au niveau métier, pas seulement dans l'UI.
    func supprimerLieu(_ lieu: Lieu) throws {
        guard !lieu.estSurMoi else {
            throw StockServiceError.lieuSurMoiNonSupprimable
        }
        contexte.delete(lieu)
        try sauvegarder()
    }

    // MARK: - Produits

    @discardableResult
    func creerProduit(
        nom: String,
        type: TypeProduit,
        cip13: String? = nil,
        refBDPMCIS: String? = nil,
        conditionnement: Int = 1,
        seuilStockBas: Int? = nil
    ) throws -> Produit {
        let produit = Produit(
            nom: nom,
            type: type,
            cip13: cip13,
            refBDPMCIS: refBDPMCIS,
            conditionnement: conditionnement,
            seuilStockBas: seuilStockBas
        )
        contexte.insert(produit)
        try sauvegarder()
        return produit
    }

    func supprimerProduit(_ produit: Produit) throws {
        contexte.delete(produit)
        try sauvegarder()
    }

    // MARK: - Stock

    /// Ajoute `quantite` unités d'un produit dans un lieu (« j'ai reçu »).
    /// Fusionne avec un lot existant de même péremption / n° de lot, sinon crée un lot.
    @discardableResult
    func ajouterStock(
        produit: Produit,
        lieu: Lieu,
        quantite: Int,
        datePeremption: Date? = nil,
        numeroLot: String? = nil,
        motif: MotifMouvement = .reception
    ) throws -> Lot {
        guard quantite > 0 else { throw StockServiceError.quantiteInvalide }

        let lot = lotFusionnable(produit: produit, lieu: lieu, datePeremption: datePeremption, numeroLot: numeroLot)
            ?? {
                let nouveau = Lot(produit: produit, lieu: lieu, quantite: 0, datePeremption: datePeremption, numeroLot: numeroLot)
                contexte.insert(nouveau)
                return nouveau
            }()
        lot.quantite += quantite

        contexte.insert(Mouvement(produit: produit, lieu: lieu, delta: quantite, motif: motif))
        try sauvegarder()
        return lot
    }

    /// Retire `quantite` unités d'un produit dans un lieu (« j'ai utilisé »),
    /// en consommant d'abord les lots qui périment le plus tôt (FEFO).
    func retirerStock(
        produit: Produit,
        lieu: Lieu,
        quantite: Int,
        motif: MotifMouvement = .usage
    ) throws {
        guard quantite > 0 else { throw StockServiceError.quantiteInvalide }

        let disponibles = lotsFEFO(produit: produit, lieu: lieu)
        let total = disponibles.reduce(0) { $0 + $1.quantite }
        guard total >= quantite else {
            throw StockServiceError.stockInsuffisant(disponible: total)
        }

        consommer(quantite, surLots: disponibles)
        contexte.insert(Mouvement(produit: produit, lieu: lieu, delta: -quantite, motif: motif))
        try sauvegarder()
    }

    // MARK: - Helpers internes (partagés avec TransfertService)

    /// Lots d'un produit dans un lieu, triés FEFO : péremption la plus proche
    /// d'abord, lots sans péremption en dernier.
    func lotsFEFO(produit: Produit, lieu: Lieu) -> [Lot] {
        produit.lots
            .filter { $0.lieu?.id == lieu.id && $0.quantite > 0 }
            .sorted {
                switch ($0.datePeremption, $1.datePeremption) {
                case let (d0?, d1?): d0 < d1
                case (.some, .none): true
                case (.none, .some): false
                case (.none, .none): $0.dateAjout < $1.dateAjout
                }
            }
    }

    /// Décrémente les lots dans l'ordre donné ; supprime les lots vidés.
    /// Précondition : le total disponible couvre `quantite`.
    func consommer(_ quantite: Int, surLots lots: [Lot]) {
        var restant = quantite
        for lot in lots where restant > 0 {
            let pris = min(lot.quantite, restant)
            lot.quantite -= pris
            restant -= pris
            if lot.quantite == 0 {
                contexte.delete(lot)
            }
        }
    }

    private func lotFusionnable(produit: Produit, lieu: Lieu, datePeremption: Date?, numeroLot: String?) -> Lot? {
        produit.lots.first {
            $0.lieu?.id == lieu.id
                && $0.datePeremption == datePeremption
                && $0.numeroLot == numeroLot
        }
    }
}
