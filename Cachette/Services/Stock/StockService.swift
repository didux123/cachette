import Foundation
import SwiftData

enum StockServiceError: LocalizedError, Equatable {
    case lieuSurMoiNonSupprimable

    var errorDescription: String? {
        switch self {
        case .lieuSurMoiNonSupprimable:
            "Le lieu « Sur moi » voyage toujours avec toi — il ne peut pas être supprimé."
        }
    }
}

/// Toutes les mutations de lieux et de stock passent par ici, jamais par les vues.
/// Les invariants métier (lieu « Sur moi » indestructible, cohérence des quantités)
/// sont garantis dans cette couche.
struct StockService {
    let contexte: ModelContext

    // MARK: - Lieux

    @discardableResult
    func creerLieu(nom: String, type: TypeLieu, emoji: String? = nil, couleurHex: String = "C8643C") throws -> Lieu {
        let ordreMax = (try? contexte.fetch(FetchDescriptor<Lieu>()))?.map(\.ordre).max() ?? 0
        let lieu = Lieu(nom: nom, type: type, emoji: emoji, couleurHex: couleurHex, ordre: ordreMax + 1)
        contexte.insert(lieu)
        try contexte.save()
        return lieu
    }

    func renommerLieu(_ lieu: Lieu, nom: String) throws {
        lieu.nom = nom
        try contexte.save()
    }

    /// Refuse la suppression du lieu spécial « Sur moi » (P0-1) — garde-fou
    /// au niveau métier, pas seulement dans l'UI.
    func supprimerLieu(_ lieu: Lieu) throws {
        guard !lieu.estSurMoi else {
            throw StockServiceError.lieuSurMoiNonSupprimable
        }
        contexte.delete(lieu)
        try contexte.save()
    }
}
