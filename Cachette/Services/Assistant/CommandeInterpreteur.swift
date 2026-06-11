import Foundation

/// Interpréteur local de commandes en français naturel — aucun réseau,
/// aucune IA distante, compatible tout iPhone. Comprend PLUSIEURS mouvements
/// dans une même phrase :
/// - « j'ai pris 1 cathéter, 2 pompes et 1 stylo » → 3 usages
/// - « je prends 3 cathéters de chez moi pour aller chez mes parents » → transfert
/// - « j'ai reçu 5 capteurs chez moi » → réception
/// - « combien il me reste de cathéters ? » → question de stock
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

    /// Une phrase → une liste d'actions (jamais vide : `.incomprise` en repli).
    static func interpreter(
        _ phrase: String,
        produits: [ProduitRef],
        lieux: [LieuRef]
    ) -> [IntentionAssistant] {
        let texte = normaliser(phrase)
        let mots = tokeniser(texte)

        let correspondances = trouverProduits(mots: mots, produits: produits)
        guard !correspondances.isEmpty else {
            return [.incomprise(raison: produits.isEmpty
                ? "Ta liste de produits suivis est vide — ajoute-en d'abord."
                : "Je n'ai pas reconnu de produit de ta liste dans la phrase.")]
        }

        // Question de stock ?
        if texte.contains("combien") || texte.contains("reste") || texte.contains("stock") {
            return correspondances.map { .stock(produit: $0.produit.id) }
        }

        let (source, destination) = trouverLieux(dans: texte, lieux: lieux)
        let verbeTransport = ["je prends", "j'emmene", "jemmene", "j'emporte", "jemporte", "je pars", "je transfere", "j'amene", "jamene"]
            .contains { texte.contains($0) }
        let estReception = ["recu", "achete", "ajoute", "rajoute", "recupere", "commande"]
            .contains(where: texte.contains)
        let estUsage = ["utilise", "consomme", "pris", "use", "pose", "termine", "fini"]
            .contains(where: texte.contains)

        // Le « moule » d'action, partagé par tous les produits de la phrase.
        func intention(produit: UUID, quantite: Int) -> IntentionAssistant? {
            if let source, let destination {
                return .transfert(produit: produit, source: source.id, destination: destination.id, quantite: quantite)
            }
            if verbeTransport, let source,
               let surMoi = lieux.first(where: \.estSurMoi), surMoi.id != source.id {
                return .transfert(produit: produit, source: source.id, destination: surMoi.id, quantite: quantite)
            }
            if verbeTransport, let destination,
               let surMoi = lieux.first(where: \.estSurMoi), surMoi.id != destination.id {
                return .transfert(produit: produit, source: surMoi.id, destination: destination.id, quantite: quantite)
            }
            if estReception {
                return .reception(produit: produit, lieu: (source ?? destination)?.id, quantite: quantite)
            }
            if estUsage {
                return .usage(produit: produit, lieu: (source ?? destination)?.id, quantite: quantite)
            }
            return nil
        }

        var actions: [IntentionAssistant] = []
        for (index, correspondance) in correspondances.enumerated() {
            let quantite = quantite(pour: correspondance, precedente: index > 0 ? correspondances[index - 1] : nil, mots: mots)
            if let action = intention(produit: correspondance.produit.id, quantite: quantite) {
                actions.append(action)
            }
        }

        guard !actions.isEmpty else {
            let noms = correspondances.map(\.produit.nom).joined(separator: ", ")
            return [.incomprise(raison: "J'ai reconnu « \(noms) » mais pas l'action. Essaie « j'ai utilisé… », « j'ai reçu… » ou « je prends… de… pour… ».")]
        }
        return actions
    }

    // MARK: - Normalisation & découpage

    static func normaliser(_ texte: String) -> String {
        texte
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
    }

    /// Pluriel naïf : suffit pour « cathéters » → « cathéter ».
    /// Les mots-nombres sont préservés (« deux » ne doit pas devenir « deu »).
    private static func singulier(_ mot: String) -> String {
        guard nombresEnLettres[mot] == nil else { return mot }
        return mot.count > 3 && (mot.hasSuffix("s") || mot.hasSuffix("x")) ? String(mot.dropLast()) : mot
    }

    /// Mots de la phrase, dans l'ordre, au singulier.
    private static func tokeniser(_ texte: String) -> [String] {
        texte.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map(singulier)
    }

    // MARK: - Produits (multi)

    nonisolated struct CorrespondanceProduit {
        let produit: ProduitRef
        /// Indices des mots de la phrase qui appartiennent au nom du produit.
        let indices: [Int]
        let score: Int

        var premierIndice: Int { indices.min() ?? 0 }
        var dernierIndice: Int { indices.max() ?? 0 }
    }

    private static let motsVides: Set<String> = ["de", "le", "la", "les", "un", "une", "des", "du", "boite"]

    /// Tous les produits cités, chacun ancré à sa position dans la phrase.
    /// En cas de chevauchement (« stylo » qui matche deux stylos), le nom le
    /// plus spécifique (meilleur score) gagne, l'autre est écarté.
    static func trouverProduits(mots: [String], produits: [ProduitRef]) -> [CorrespondanceProduit] {
        var candidats: [CorrespondanceProduit] = []

        for produit in produits {
            let motsNom = tokeniser(normaliser(produit.nom))
            let significatifs = motsNom.filter { !motsVides.contains($0) && $0.count > 2 }
            let cibles = Set(significatifs.isEmpty ? motsNom : significatifs)

            let indices = mots.indices.filter { index in
                cibles.contains { motsProches(mots[index], $0) }
            }
            guard !indices.isEmpty else { continue }
            // Score = nombre de mots distincts du nom retrouvés dans la phrase.
            let score = cibles.count { cible in
                mots.contains { motsProches($0, cible) }
            }
            candidats.append(CorrespondanceProduit(produit: produit, indices: indices, score: score))
        }

        // Les plus spécifiques d'abord, puis on n'accepte que les disjoints.
        candidats.sort {
            $0.score != $1.score ? $0.score > $1.score : $0.produit.nom.count > $1.produit.nom.count
        }
        var indicesUtilises = Set<Int>()
        var retenus: [CorrespondanceProduit] = []
        for candidat in candidats {
            guard indicesUtilises.isDisjoint(with: candidat.indices) else { continue }
            indicesUtilises.formUnion(candidat.indices)
            retenus.append(candidat)
        }
        return retenus.sorted { $0.premierIndice < $1.premierIndice }
    }

    /// La quantité d'un produit = le nombre le plus proche AVANT sa mention,
    /// sans remonter au-delà du produit précédent (« 1 cathéter, 2 pompes »).
    private static func quantite(
        pour correspondance: CorrespondanceProduit,
        precedente: CorrespondanceProduit?,
        mots: [String]
    ) -> Int {
        let debut = precedente.map { $0.dernierIndice + 1 } ?? 0
        let fin = correspondance.premierIndice
        guard debut <= fin else { return 1 }
        for index in stride(from: fin - 1, through: debut, by: -1) where index >= 0 {
            if let nombre = nombre(depuis: mots[index]) {
                return nombre
            }
        }
        return 1
    }

    // MARK: - Lieux

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
        // Noms qui se chevauchent à la même position : le plus long gagne.
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

    // MARK: - Tolérance aux fautes de frappe

    /// Deux mots sont « proches » si leur distance d'édition tient dans la
    /// tolérance : 1 faute pour 4-6 lettres, 2 fautes dès 7 lettres, exact en
    /// dessous. La première lettre doit correspondre (limite les faux amis).
    static func motsProches(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        guard a.first == b.first else { return false }
        let tolerance = max(a.count, b.count) >= 7 ? 2 : (min(a.count, b.count) >= 4 ? 1 : 0)
        guard tolerance > 0, abs(a.count - b.count) <= tolerance else { return false }
        return distanceEdition(a, b) <= tolerance
    }

    /// Levenshtein classique (les mots comparés font < 30 caractères).
    private static func distanceEdition(_ a: String, _ b: String) -> Int {
        let lettresA = Array(a), lettresB = Array(b)
        var precedente = Array(0...lettresB.count)
        var courante = [Int](repeating: 0, count: lettresB.count + 1)

        for (i, lettreA) in lettresA.enumerated() {
            courante[0] = i + 1
            for (j, lettreB) in lettresB.enumerated() {
                courante[j + 1] = lettreA == lettreB
                    ? precedente[j]
                    : 1 + min(precedente[j], precedente[j + 1], courante[j])
            }
            swap(&precedente, &courante)
        }
        return precedente[lettresB.count]
    }

    // MARK: - Nombres

    private static let nombresEnLettres: [String: Int] = [
        "un": 1, "une": 1, "deux": 2, "trois": 3, "quatre": 4, "cinq": 5,
        "six": 6, "sept": 7, "huit": 8, "neuf": 9, "dix": 10,
        "onze": 11, "douze": 12, "quinze": 15, "vingt": 20, "trente": 30,
    ]

    private static func nombre(depuis mot: String) -> Int? {
        if let nombre = Int(mot), (1...9999).contains(nombre) {
            return nombre
        }
        return nombresEnLettres[mot]
    }
}
