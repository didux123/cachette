import Foundation

/// Extraction de dates de péremption depuis du texte OCR de boîtes françaises.
/// Pur et synchrone → testable sur corpus sans caméra.
nonisolated enum ExpiryDateParser {

    /// Dates candidates plausibles, la plus probable en premier.
    /// Heuristiques :
    /// - une ligne marquée EXP / PER / « utiliser avant » est prioritaire ;
    /// - une date sans jour = dernier jour du mois ;
    /// - plausible = entre (référence − 1 mois) et (référence + 8 ans) —
    ///   élimine les dates de fabrication, déjà passées.
    static func meilleuresDates(dans lignes: [String], reference: Date = .now) -> [Date] {
        let calendrier = Calendar(identifier: .gregorian)
        let plancher = calendrier.date(byAdding: .month, value: -1, to: reference)!
        let plafond = calendrier.date(byAdding: .year, value: 8, to: reference)!

        var scores: [(date: Date, prioritaire: Bool)] = []

        for ligne in lignes {
            let majuscules = ligne.uppercased()
            let prioritaire = ["EXP", "PER", "UTILISER AVANT", "AVANT LE", "USE BY"]
                .contains { majuscules.contains($0) }

            for date in datesDansLigne(majuscules, calendrier: calendrier)
            where date >= plancher && date <= plafond {
                scores.append((date, prioritaire))
            }
        }

        var vues = Set<Date>()
        return scores
            .sorted {
                if $0.prioritaire != $1.prioritaire { return $0.prioritaire }
                return $0.date < $1.date
            }
            .map(\.date)
            .filter { vues.insert($0).inserted }
    }

    // MARK: - Détection par motifs

    private static let mois: [(motif: String, numero: Int)] = [
        ("JANV", 1), ("JAN", 1),
        ("FEVR", 2), ("FÉVR", 2), ("FEV", 2), ("FÉV", 2),
        ("MARS", 3), ("MAR", 3),
        ("AVRIL", 4), ("AVR", 4),
        ("MAI", 5),
        ("JUIN", 6),
        ("JUILLET", 7), ("JUIL", 7), ("JUL", 7),
        ("AOUT", 8), ("AOÛT", 8), ("AOU", 8),
        ("SEPT", 9), ("SEP", 9),
        ("OCTOBRE", 10), ("OCT", 10),
        ("NOVEMBRE", 11), ("NOV", 11),
        ("DECEMBRE", 12), ("DÉCEMBRE", 12), ("DEC", 12), ("DÉC", 12),
    ]

    private static func datesDansLigne(_ ligne: String, calendrier: Calendar) -> [Date] {
        var resultats: [Date] = []

        // JJ/MM/AAAA ou JJ.MM.AAAA ou JJ-MM-AAAA
        let motifComplet = /\b(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{4})\b/
        for correspondance in ligne.matches(of: motifComplet) {
            resultats.append(contentsOf: construire(
                jour: Int(correspondance.1), mois: Int(correspondance.2)!, annee: Int(correspondance.3)!,
                calendrier: calendrier
            ))
        }
        // Les dates complètes (même invalides comme 31/02/2027) sont masquées
        // pour que les motifs partiels ne re-matchent pas leurs fragments.
        let ligne = ligne.replacing(motifComplet, with: " ")

        // MM/AAAA, MM-AAAA, MM.AAAA (sans jour → fin de mois)
        for correspondance in ligne.matches(of: /\b(\d{1,2})[\/\.\-](\d{4})\b/) {
            resultats.append(contentsOf: construire(
                jour: nil, mois: Int(correspondance.1)!, annee: Int(correspondance.2)!,
                calendrier: calendrier
            ))
        }

        // AAAA-MM ou AAAA/MM (format ISO partiel)
        for correspondance in ligne.matches(of: /\b(\d{4})[\/\.\-](\d{1,2})\b/) {
            resultats.append(contentsOf: construire(
                jour: nil, mois: Int(correspondance.2)!, annee: Int(correspondance.1)!,
                calendrier: calendrier
            ))
        }

        // MM/AA (année sur 2 chiffres) — uniquement si rien d'autre n'a matché,
        // car trop ambigu (« 12/26 » peut être un n° de lot).
        if resultats.isEmpty {
            for correspondance in ligne.matches(of: /\b(\d{1,2})[\/\.\-](\d{2})\b/) {
                resultats.append(contentsOf: construire(
                    jour: nil, mois: Int(correspondance.1)!, annee: 2000 + Int(correspondance.2)!,
                    calendrier: calendrier
                ))
            }
        }

        // Mois en toutes lettres : « AOÛT 2026 », « 15 AOUT 2026 », « DÉC. 2027 »
        for (motif, numero) in mois {
            guard let plage = ligne.range(of: motif) else { continue }
            let suite = ligne[plage.upperBound...]
            guard let anneeMatch = suite.firstMatch(of: /\b(20\d{2})\b/) else { continue }
            let avant = ligne[..<plage.lowerBound]
            let jour = avant.matches(of: /(\d{1,2})\s*$/).last.flatMap { Int($0.1) }
            resultats.append(contentsOf: construire(
                jour: jour, mois: numero, annee: Int(anneeMatch.1)!,
                calendrier: calendrier
            ))
            break // un seul mois en lettres par ligne
        }

        return resultats
    }

    private static func construire(jour: Int?, mois: Int, annee: Int, calendrier: Calendar) -> [Date] {
        guard (1...12).contains(mois), (2000...2099).contains(annee) else { return [] }
        var composants = DateComponents(year: annee, month: mois)

        if let jour {
            guard (1...31).contains(jour) else { return [] }
            composants.day = jour
            guard let date = calendrier.date(from: composants),
                  calendrier.component(.month, from: date) == mois // rejette le 31/02 etc.
            else { return [] }
            return [date]
        }

        // Sans jour : dernier jour du mois.
        composants.day = 1
        guard let premier = calendrier.date(from: composants),
              let moisSuivant = calendrier.date(byAdding: .month, value: 1, to: premier),
              let dernier = calendrier.date(byAdding: .day, value: -1, to: moisSuivant)
        else { return [] }
        return [dernier]
    }
}
