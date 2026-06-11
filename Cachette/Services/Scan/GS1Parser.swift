import Foundation

/// Données extraites d'un Datamatrix GS1 de boîte de médicament française.
/// La plupart des boîtes encodent GTIN + péremption + lot : on récupère tout
/// sans OCR ni saisie.
nonisolated struct GS1Payload: Equatable {
    var gtin14: String?
    var datePeremption: Date?
    var numeroLot: String?
    var numeroSerie: String?

    /// CIP13 français = les 13 derniers chiffres du GTIN-14
    /// (le GTIN des médicaments FR commence par 0 + 3400…).
    var cip13: String? {
        guard let gtin14, gtin14.count == 14 else { return nil }
        let cip = String(gtin14.dropFirst())
        return cip.hasPrefix("34") ? cip : cip
    }
}

/// Parseur tolérant des Application Identifiers GS1 (AI) :
/// - `01` GTIN-14 (longueur fixe 14)
/// - `17` date d'expiration AAMMJJ (fixe 6, jour 00 = fin de mois)
/// - `11` date de fabrication (fixe 6, ignorée mais consommée)
/// - `15` date de durabilité minimale (fixe 6, repli si pas de 17)
/// - `10` n° de lot (variable, terminé par GS U+001D ou fin de chaîne)
/// - `21` n° de série (variable)
/// Tolère : préfixe d'identifiant de symbologie `]d2`, GS manquants,
/// AI dans un ordre quelconque.
nonisolated enum GS1Parser {
    private static let gs = Character(UnicodeScalar(0x1D))

    static func parse(_ brut: String) -> GS1Payload? {
        var chaine = Substring(brut)

        // Identifiant de symbologie éventuel : "]d2" (Datamatrix), "]C1" (GS1-128)…
        if chaine.first == "]" {
            chaine = chaine.dropFirst(3)
        }

        var payload = GS1Payload()
        var dateDurabilite: Date?

        while !chaine.isEmpty {
            // Un GS peut traîner entre deux AI : on le saute.
            while chaine.first == gs { chaine = chaine.dropFirst() }
            guard chaine.count >= 2 else { break }

            let ai = String(chaine.prefix(2))
            chaine = chaine.dropFirst(2)

            switch ai {
            case "01":
                guard let valeur = prendreFixe(14, dans: &chaine), valeur.allSatisfy(\.isNumber) else { return resultat(payload) }
                payload.gtin14 = valeur
            case "17":
                guard let valeur = prendreFixe(6, dans: &chaine) else { return resultat(payload) }
                payload.datePeremption = date(depuisAAMMJJ: valeur)
            case "15":
                guard let valeur = prendreFixe(6, dans: &chaine) else { return resultat(payload) }
                dateDurabilite = date(depuisAAMMJJ: valeur)
            case "11":
                guard prendreFixe(6, dans: &chaine) != nil else { return resultat(payload) }
            case "10":
                payload.numeroLot = prendreVariable(dans: &chaine)
            case "21":
                payload.numeroSerie = prendreVariable(dans: &chaine)
            default:
                // AI inconnu : impossible de connaître sa longueur de façon
                // fiable → on s'arrête en gardant ce qu'on a déjà.
                return resultat(payload, repli: dateDurabilite)
            }
        }
        return resultat(payload, repli: dateDurabilite)
    }

    private static func resultat(_ payload: GS1Payload, repli dateDurabilite: Date? = nil) -> GS1Payload? {
        var final = payload
        if final.datePeremption == nil { final.datePeremption = dateDurabilite }
        // Un payload sans GTIN ni date ni lot n'est pas un GS1 utile.
        return (final.gtin14 != nil || final.datePeremption != nil || final.numeroLot != nil) ? final : nil
    }

    private static func prendreFixe(_ longueur: Int, dans chaine: inout Substring) -> String? {
        guard chaine.count >= longueur else { return nil }
        let valeur = String(chaine.prefix(longueur))
        chaine = chaine.dropFirst(longueur)
        return valeur
    }

    private static func prendreVariable(dans chaine: inout Substring) -> String? {
        if let indexGS = chaine.firstIndex(of: gs) {
            let valeur = String(chaine[..<indexGS])
            chaine = chaine[chaine.index(after: indexGS)...]
            return valeur.isEmpty ? nil : valeur
        }
        let valeur = String(chaine)
        chaine = Substring()
        return valeur.isEmpty ? nil : valeur
    }

    /// AAMMJJ GS1 → Date. Jour « 00 » = dernier jour du mois (cas fréquent
    /// sur les boîtes). Années 00-99 → 2000-2099.
    static func date(depuisAAMMJJ valeur: String) -> Date? {
        guard valeur.count == 6, valeur.allSatisfy(\.isNumber),
              let aa = Int(valeur.prefix(2)),
              let mm = Int(valeur.dropFirst(2).prefix(2)),
              let jj = Int(valeur.suffix(2)),
              (1...12).contains(mm)
        else { return nil }

        var composants = DateComponents()
        composants.year = 2000 + aa
        composants.month = mm

        let calendrier = Calendar(identifier: .gregorian)
        if jj == 0 {
            // Fin de mois : 1er du mois suivant − 1 jour.
            composants.day = 1
            guard let premierDuMois = calendrier.date(from: composants),
                  let moisSuivant = calendrier.date(byAdding: .month, value: 1, to: premierDuMois)
            else { return nil }
            return calendrier.date(byAdding: .day, value: -1, to: moisSuivant)
        }
        composants.day = jj
        guard (1...31).contains(jj), let date = calendrier.date(from: composants) else { return nil }
        return date
    }
}
