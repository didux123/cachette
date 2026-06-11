import Foundation

/// Interpréteur local de commandes en français naturel — aucun réseau,
/// aucune IA distante. Comprend :
/// - transfert : « je prends 3 cathéters de chez moi pour aller chez mes parents »
/// - usage     : « j'ai utilisé 2 bandelettes », « j'utilise un stylo »
/// - réception : « j'ai reçu 5 capteurs », « ajoute 2 boîtes de doliprane chez moi »
/// - stock     : « combien il me reste de cathéters ? »
nonisolated enum IntentionAssistant: Equatable {
    case transfert(produit: UUID, source: UUID, destination: UUID, quantite: Int)
    case usage(produit: UUID, lieu: UUID?, quantite: Int)
    case reception(produit: UUID, lieu: UUID?, quantite: Int)
    case stock(produit: UUID)
    case incomprise(raison: String)
}

nonisolated struct ProduitRef {
    let id: UUID
    let nom: String
}

nonisolated struct LieuRef {
    let id: UUID
    let nom: String
    let estSurMoi: Bool
}

nonisolated enum CommandeInterpreteur {

    static func interpreter(
        _ phrase: String,
        produits: [ProduitRef],
        lieux: [LieuRef]
    ) -> IntentionAssistant {
        let texte = normaliser(phrase)

        guard let produit = trouverProduit(dans: texte, produits: produits) else {
            return .incomprise(raison: produits.isEmpty
                ? "Ta liste de produits suivis est vide — ajoute-en d'abord."
                : "Je n'ai pas reconnu de produit de ta liste dans la phrase.")
        }

        // Question de stock ?
        if texte.contains("combien") || texte.contains("reste") || texte.contains("stock") {
            return .stock(produit: produit.id)
        }

        let quantite = extraireQuantite(de: texte) ?? 1
        let (source, destination) = trouverLieux(dans: texte, lieux: lieux)

        // Deux lieux (ou un départ + « je prends/j'emmène/je pars ») = transfert.
        let verbeTransport = ["je prends", "j'emmene", "jemmene", "j'emporte", "jemporte", "je pars", "je transfere", "j'amene", "jamene"]
            .contains { texte.contains($0) }

        if let source, let destination {
            return .transfert(produit: produit.id, source: source.id, destination: destination.id, quantite: quantite)
        }
        if verbeTransport, let source {
            // Destination implicite : « Sur moi » (le pochon qui voyage).
            if let surMoi = lieux.first(where: \.estSurMoi), surMoi.id != source.id {
                return .transfert(produit: produit.id, source: source.id, destination: surMoi.id, quantite: quantite)
            }
        }
        if verbeTransport, let destination {
            // « j'emmène 3 stylos chez mes parents » : source implicite = Sur moi.
            if let surMoi = lieux.first(where: \.estSurMoi), surMoi.id != destination.id {
                return .transfert(produit: produit.id, source: surMoi.id, destination: destination.id, quantite: quantite)
            }
        }

        // Réception ?
        if ["recu", "reçu", "achete", "ajoute", "rajoute", "recupere", "commande"].contains(where: texte.contains) {
            return .reception(produit: produit.id, lieu: (source ?? destination)?.id, quantite: quantite)
        }

        // Usage ?
        if ["utilise", "consomme", "pris", "use", "pose", "termine", "fini"].contains(where: texte.contains) {
            return .usage(produit: produit.id, lieu: (source ?? destination)?.id, quantite: quantite)
        }

        return .incomprise(raison: "J'ai reconnu « \(produit.nom) » mais pas l'action. Essaie « j'ai utilisé… », « j'ai reçu… » ou « je prends… de… pour… ».")
    }

    // MARK: - Normalisation

    static func normaliser(_ texte: String) -> String {
        texte
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
    }

    private static func tokens(_ texte: String) -> [String] {
        texte.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map(singulier)
    }

    /// Pluriel naïf : suffit pour « cathéters » → « cathéter ».
    private static func singulier(_ mot: String) -> String {
        mot.count > 3 && (mot.hasSuffix("s") || mot.hasSuffix("x")) ? String(mot.dropLast()) : mot
    }

    // MARK: - Entités

    /// Produit dont le nom partage le plus de tokens significatifs avec la phrase.
    static func trouverProduit(dans texte: String, produits: [ProduitRef]) -> ProduitRef? {
        let motsPhrase = Set(tokens(texte))
        let vides: Set<String> = ["de", "le", "la", "les", "un", "une", "des", "du", "boite"]

        var meilleur: (produit: ProduitRef, score: Int)?
        for produit in produits {
            let motsNom = tokens(normaliser(produit.nom))
            let significatifs = motsNom.filter { !vides.contains($0) && $0.count > 2 }
            let cibles = significatifs.isEmpty ? motsNom : significatifs
            let score = cibles.count(where: motsPhrase.contains)
            if score > 0, score >= (meilleur?.score ?? 0) {
                meilleur = (produit, score)
            }
        }
        return meilleur?.produit
    }

    /// Repère les lieux cités et leur rôle (source/destination) d'après le mot
    /// qui précède : « de/depuis » = départ, « vers/pour/aller/à/au » = arrivée.
    static func trouverLieux(dans texte: String, lieux: [LieuRef]) -> (source: LieuRef?, destination: LieuRef?) {
        struct Occurrence {
            let lieu: LieuRef
            let position: String.Index
            let estSource: Bool?
        }

        var occurrences: [Occurrence] = []
        for lieu in lieux {
            let nom = normaliser(lieu.nom)
            var depart = texte.startIndex
            while let plage = texte.range(of: nom, range: depart..<texte.endIndex) {
                let avant = String(texte[..<plage.lowerBound])
                let motsAvant = avant.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
                let dernier = motsAvant.last ?? ""
                let avantDernier = motsAvant.dropLast().last ?? ""

                var estSource: Bool?
                if ["de", "depuis", "du"].contains(dernier) {
                    estSource = true
                } else if ["vers", "pour", "a", "au", "aller", "dans", "direction"].contains(dernier)
                            || ["aller", "vers", "pour"].contains(avantDernier) {
                    estSource = false
                }
                occurrences.append(Occurrence(lieu: lieu, position: plage.lowerBound, estSource: estSource))
                depart = plage.upperBound
            }
        }
        // « chez mes parents » contient « chez moi » ? Non, mais des noms peuvent
        // se chevaucher : on garde l'occurrence au nom le plus long par position.
        occurrences.sort { $0.position < $1.position }
        var filtrees: [Occurrence] = []
        for occurrence in occurrences {
            if let derniere = filtrees.last, derniere.position == occurrence.position {
                if occurrence.lieu.nom.count > derniere.lieu.nom.count {
                    filtrees[filtrees.count - 1] = occurrence
                }
            } else {
                filtrees.append(occurrence)
            }
        }

        var source = filtrees.first { $0.estSource == true }?.lieu
        var destination = filtrees.first { $0.estSource == false }?.lieu

        // Les non-marqués comblent les trous, dans l'ordre de la phrase.
        let libres = filtrees.filter { $0.estSource == nil }.map(\.lieu)
        for lieu in libres {
            if source == nil, lieu.id != destination?.id {
                source = lieu
            } else if destination == nil, lieu.id != source?.id {
                destination = lieu
            }
        }
        if source?.id == destination?.id { destination = nil }
        return (source, destination)
    }

    // MARK: - Quantité

    private static let nombresEnLettres: [String: Int] = [
        "un": 1, "une": 1, "deux": 2, "trois": 3, "quatre": 4, "cinq": 5,
        "six": 6, "sept": 7, "huit": 8, "neuf": 9, "dix": 10,
        "onze": 11, "douze": 12, "quinze": 15, "vingt": 20, "trente": 30,
    ]

    static func extraireQuantite(de texte: String) -> Int? {
        if let correspondance = texte.firstMatch(of: /\b(\d{1,4})\b/),
           let nombre = Int(correspondance.1) {
            return nombre
        }
        for mot in texte.components(separatedBy: CharacterSet.alphanumerics.inverted) {
            if let nombre = nombresEnLettres[mot] {
                return nombre
            }
        }
        return nil
    }
}
