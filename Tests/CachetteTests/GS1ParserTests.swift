import Foundation
import Testing
@testable import Cachette

struct GS1ParserTests {
    private let gs = String(UnicodeScalar(0x1D))

    @Test func payloadCompletClassique() throws {
        // 01 GTIN + 17 péremption + 10 lot (GS) + 21 série — l'ordre type des boîtes FR.
        let payload = try #require(GS1Parser.parse("01034009359558381727091510AB12C\(gs)21XYZ987"))

        #expect(payload.gtin14 == "03400935955838")
        #expect(payload.cip13 == "3400935955838")
        #expect(payload.numeroLot == "AB12C")
        #expect(payload.numeroSerie == "XYZ987")

        let composants = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month, .day], from: try #require(payload.datePeremption))
        #expect(composants.year == 2027)
        #expect(composants.month == 9)
        #expect(composants.day == 15)
    }

    @Test func jourZeroDevientFinDeMois() throws {
        let payload = try #require(GS1Parser.parse("0103400935955838172602 00".replacingOccurrences(of: " ", with: "")))
        let composants = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month, .day], from: try #require(payload.datePeremption))
        #expect(composants.year == 2026)
        #expect(composants.month == 2)
        #expect(composants.day == 28)
    }

    @Test func lotEnFinDeChaineSansGS() throws {
        let payload = try #require(GS1Parser.parse("010340093595583810LOT42"))
        #expect(payload.numeroLot == "LOT42")
        #expect(payload.cip13 == "3400935955838")
    }

    @Test func prefixeDeSymbologieEstIgnore() throws {
        let payload = try #require(GS1Parser.parse("]d20103400935955838"))
        #expect(payload.cip13 == "3400935955838")
    }

    @Test func ordreDesAIQuelconque() throws {
        let payload = try #require(GS1Parser.parse("1726063010LOT1\(gs)0103400935955838"))
        #expect(payload.cip13 == "3400935955838")
        #expect(payload.numeroLot == "LOT1")
        #expect(payload.datePeremption != nil)
    }

    @Test func aiInconnuArreteSansPerdreLAcquis() throws {
        // AI 90 (interne) après le GTIN : on garde le GTIN, on ignore la suite.
        let payload = try #require(GS1Parser.parse("010340093595583890DONNEES_INTERNES"))
        #expect(payload.cip13 == "3400935955838")
    }

    @Test func dateDurabilite15EnRepliDe17() throws {
        let payload = try #require(GS1Parser.parse("010340093595583815271231"))
        let composants = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month], from: try #require(payload.datePeremption))
        #expect(composants.year == 2027)
        #expect(composants.month == 12)
    }

    @Test func chaineNonGS1EstRejetee() {
        #expect(GS1Parser.parse("hello world") == nil)
        #expect(GS1Parser.parse("") == nil)
        #expect(GS1Parser.parse("3400935955838") == nil) // EAN-13 nu : géré en amont, pas par le parser GS1
    }

    @Test func gtinInvalideEstRejete() {
        // AI 01 suivi de moins de 14 caractères.
        #expect(GS1Parser.parse("01123") == nil)
    }
}

struct BDPMDatabaseTests {
    @Test func laBaseEmbarqueeRepondAuxRequetes() throws {
        let base = try BDPMDatabase()
        #expect(try base.nombreDePresentations() > 10_000)
        #expect(try base.dateSnapshot() != nil)
    }

    @Test func resolutionDolipraneParCIP13() throws {
        let base = try BDPMDatabase()
        let presentation = try #require(try base.presentation(cip13: "3400935955838"))
        #expect(presentation.denomination.uppercased().contains("DOLIPRANE"))
        #expect(presentation.unitesParBoite == 8)
    }

    @Test func cip13InconnuRenvoieNil() throws {
        let base = try BDPMDatabase()
        #expect(try base.presentation(cip13: "9999999999999") == nil)
    }
}
