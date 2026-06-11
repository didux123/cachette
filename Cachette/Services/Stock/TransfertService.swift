import Foundation
import SwiftData

enum TransfertError: LocalizedError, Equatable {
    case memeLieu

    var errorDescription: String? {
        switch self {
        case .memeLieu: "Choisis deux lieux différents pour le transfert."
        }
    }
}

/// Transfert de stock entre deux lieux (« je pars avec N sur moi », P0-2b) :
/// décrémente la source et incrémente la destination en une seule opération,
/// journalisée comme deux Mouvements liés par un même `transfertID`.
struct TransfertService {
    let contexte: ModelContext

    @discardableResult
    func transferer(
        produit: Produit,
        de source: Lieu,
        vers destination: Lieu,
        quantite: Int,
        date: Date = .now
    ) throws -> UUID {
        guard source.id != destination.id else { throw TransfertError.memeLieu }
        guard quantite > 0 else { throw StockServiceError.quantiteInvalide }

        let stock = StockService(contexte: contexte)
        let lotsSource = stock.lotsFEFO(produit: produit, lieu: source)
        let disponible = lotsSource.reduce(0) { $0 + $1.quantite }
        guard disponible >= quantite else {
            throw StockServiceError.stockInsuffisant(disponible: disponible)
        }

        // Déplacement lot par lot (FEFO) : la péremption et le n° de lot suivent
        // physiquement les unités déplacées.
        var restant = quantite
        for lot in lotsSource where restant > 0 {
            let pris = min(lot.quantite, restant)
            restant -= pris

            if let miroir = lotMiroir(de: lot, produit: produit, dans: destination) {
                miroir.quantite += pris
            } else {
                contexte.insert(
                    Lot(
                        produit: produit,
                        lieu: destination,
                        quantite: pris,
                        datePeremption: lot.datePeremption,
                        numeroLot: lot.numeroLot
                    )
                )
            }

            lot.quantite -= pris
            if lot.quantite == 0 {
                contexte.delete(lot)
            }
        }

        let transfertID = UUID()
        contexte.insert(
            Mouvement(produit: produit, lieu: source, delta: -quantite, motif: .transfertSortie, date: date, transfertID: transfertID)
        )
        contexte.insert(
            Mouvement(produit: produit, lieu: destination, delta: quantite, motif: .transfertEntree, date: date, transfertID: transfertID)
        )

        // Sauvegarde unique : soit tout passe, soit rien (atomicité).
        do {
            try contexte.save()
        } catch {
            contexte.rollback()
            throw error
        }
        return transfertID
    }

    private func lotMiroir(de lot: Lot, produit: Produit, dans lieu: Lieu) -> Lot? {
        produit.lots.first {
            $0.lieu?.id == lieu.id
                && $0.datePeremption == lot.datePeremption
                && $0.numeroLot == lot.numeroLot
                && $0.id != lot.id
        }
    }
}
