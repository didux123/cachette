import Foundation
import SwiftData

/// Crée les lieux par défaut au premier lancement. Idempotent :
/// relancer l'app ne duplique jamais rien.
enum SeedService {
    static func seedSiNecessaire(contexte: ModelContext) throws {
        // Le lieu « Sur moi » est l'invariant : s'il existe, le seed a déjà eu lieu.
        let surMoiExiste = try contexte.fetchCount(
            FetchDescriptor<Lieu>(predicate: #Predicate { $0.estSurMoi })
        ) > 0
        guard !surMoiExiste else { return }

        let chezMoi = Lieu(nom: "Chez moi", type: .domicile, ordre: 0)
        let surMoi = Lieu(nom: "Sur moi", type: .surMoi, estSurMoi: true, ordre: 1)
        contexte.insert(chezMoi)
        contexte.insert(surMoi)
        try contexte.save()
    }
}
