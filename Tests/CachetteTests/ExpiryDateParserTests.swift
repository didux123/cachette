import Foundation
import Testing
@testable import Cachette

struct ExpiryDateParserTests {
    /// Référence stable pour des tests déterministes : 15 juin 2026.
    private let reference = Calendar(identifier: .gregorian)
        .date(from: DateComponents(year: 2026, month: 6, day: 15))!

    private func composants(_ date: Date) -> (annee: Int, mois: Int, jour: Int) {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return (c.year!, c.month!, c.day!)
    }

    @Test func formatMMsurAAAA() throws {
        let dates = ExpiryDateParser.meilleuresDates(dans: ["EXP 08/2027"], reference: reference)
        let premiere = try #require(dates.first)
        #expect(composants(premiere) == (2027, 8, 31))
    }

    @Test func formatJJMMAAAA() throws {
        let dates = ExpiryDateParser.meilleuresDates(dans: ["Utiliser avant le 03/11/2026"], reference: reference)
        let premiere = try #require(dates.first)
        #expect(composants(premiere) == (2026, 11, 3))
    }

    @Test func formatPointEtTiret() throws {
        for texte in ["EXP 09.2027", "EXP 09-2027"] {
            let dates = ExpiryDateParser.meilleuresDates(dans: [texte], reference: reference)
            let premiere = try #require(dates.first, "échec pour \(texte)")
            #expect(composants(premiere) == (2027, 9, 30))
        }
    }

    @Test func formatISOPartiel() throws {
        let dates = ExpiryDateParser.meilleuresDates(dans: ["2027-03"], reference: reference)
        let premiere = try #require(dates.first)
        #expect(composants(premiere) == (2027, 3, 31))
    }

    @Test func moisEnToutesLettres() throws {
        let dates = ExpiryDateParser.meilleuresDates(dans: ["AOÛT 2026"], reference: reference)
        let premiere = try #require(dates.first)
        #expect(composants(premiere) == (2026, 8, 31))
    }

    @Test func moisAbregeAvecJour() throws {
        let dates = ExpiryDateParser.meilleuresDates(dans: ["15 DEC. 2027"], reference: reference)
        let premiere = try #require(dates.first)
        #expect(composants(premiere) == (2027, 12, 15))
    }

    @Test func anneeSurDeuxChiffres() throws {
        let dates = ExpiryDateParser.meilleuresDates(dans: ["EXP 04/28"], reference: reference)
        let premiere = try #require(dates.first)
        #expect(composants(premiere) == (2028, 4, 30))
    }

    @Test func laLigneEXPGagneSurLaDateDeFabrication() throws {
        // Boîte typique : fabrication (passée, hors fenêtre) + péremption marquée EXP.
        let dates = ExpiryDateParser.meilleuresDates(
            dans: ["FAB 01/2025", "LOT AB123", "EXP 01/2028"],
            reference: reference
        )
        let premiere = try #require(dates.first)
        #expect(composants(premiere) == (2028, 1, 31))
        // La date de fabrication (jan 2025, passée) est éliminée par plausibilité.
        #expect(dates.count == 1)
    }

    @Test func lesDatesImplausiblesSontEliminees() {
        let dates = ExpiryDateParser.meilleuresDates(
            dans: ["EXP 01/2020", "EXP 06/2045", "n° 99/9999"],
            reference: reference
        )
        #expect(dates.isEmpty)
    }

    @Test func dateInvalideEstRejetee() {
        let dates = ExpiryDateParser.meilleuresDates(dans: ["31/02/2027"], reference: reference)
        #expect(dates.isEmpty)
    }

    @Test func texteSansDateNeRenvoieRien() {
        let dates = ExpiryDateParser.meilleuresDates(
            dans: ["DOLIPRANE 1000 mg", "comprimés", "Boîte de 8"],
            reference: reference
        )
        #expect(dates.isEmpty)
    }

    @Test func plusieursLignesDonnentPlusieursCandidatesOrdonnees() throws {
        let dates = ExpiryDateParser.meilleuresDates(
            dans: ["12/2026", "EXP 08/2027"],
            reference: reference
        )
        #expect(dates.count == 2)
        // La ligne EXP passe devant malgré une date plus lointaine.
        #expect(composants(try #require(dates.first)) == (2027, 8, 31))
    }
}
