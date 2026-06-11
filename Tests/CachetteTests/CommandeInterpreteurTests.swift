import Foundation
import Testing
@testable import Cachette

struct CommandeInterpreteurTests {
    // Référentiel type : 4 produits, 3 lieux dont « Sur moi ».
    private let catheters = ProduitRef(id: UUID(), nom: "Cathéters")
    private let pompes = ProduitRef(id: UUID(), nom: "Pompes à insuline")
    private let bandelettes = ProduitRef(id: UUID(), nom: "Bandelettes")
    private let stylos = ProduitRef(id: UUID(), nom: "Stylo insuline rapide")

    private let chezMoi = LieuRef(id: UUID(), nom: "Chez moi", estSurMoi: false)
    private let parents = LieuRef(id: UUID(), nom: "Chez mes parents", estSurMoi: false)
    private let surMoi = LieuRef(id: UUID(), nom: "Sur moi", estSurMoi: true)

    private var produits: [ProduitRef] { [catheters, pompes, bandelettes, stylos] }
    private var lieux: [LieuRef] { [chezMoi, parents, surMoi] }

    private func interpreter(_ phrase: String) -> [IntentionAssistant] {
        CommandeInterpreteur.interpreter(phrase, produits: produits, lieux: lieux)
    }

    // MARK: - Multi-actions (la demande de Maxence)

    @Test func troisMouvementsDansUnePhrase() {
        let intentions = interpreter("j'ai pris 1 cathéter, 2 pompes et 1 stylo")
        #expect(intentions.count == 3)
        // « j'ai pris » sans lieux = usage ; chaque produit garde SA quantité.
        #expect(intentions[0] == .usage(produit: catheters.id, lieu: nil, quantite: 1))
        #expect(intentions[1] == .usage(produit: pompes.id, lieu: nil, quantite: 2))
        #expect(intentions[2] == .usage(produit: stylos.id, lieu: nil, quantite: 1))
    }

    @Test func transfertMultiple() {
        let intentions = interpreter("je prends 2 stylos et 3 bandelettes de chez moi pour aller chez mes parents")
        #expect(intentions.count == 2)
        #expect(intentions[0] == .transfert(produit: stylos.id, source: chezMoi.id, destination: parents.id, quantite: 2))
        #expect(intentions[1] == .transfert(produit: bandelettes.id, source: chezMoi.id, destination: parents.id, quantite: 3))
    }

    @Test func receptionMultipleAvecNombresEnLettres() {
        let intentions = interpreter("j'ai reçu deux pompes et cinq bandelettes chez moi")
        #expect(intentions == [
            .reception(produit: pompes.id, lieu: chezMoi.id, quantite: 2),
            .reception(produit: bandelettes.id, lieu: chezMoi.id, quantite: 5),
        ])
    }

    // MARK: - Actions simples

    @Test func jaiDeplaceDeAVersA() {
        #expect(interpreter("j'ai déplacé 2 stylos de chez moi à chez mes parents") == [.transfert(
            produit: stylos.id, source: chezMoi.id, destination: parents.id, quantite: 2
        )])
    }

    @Test func deplacerSansDestinationVaSurMoi() {
        // « j'ai déplacé … de chez moi » tout court → le pochon (Sur moi).
        #expect(interpreter("j'ai déplacé 1 cathéter de chez moi") == [.transfert(
            produit: catheters.id, source: chezMoi.id, destination: surMoi.id, quantite: 1
        )])
    }

    @Test func laPhraseExempleDeMaxence() {
        let intentions = interpreter("Je prends 3 cathéters de chez moi pour aller chez mes parents")
        #expect(intentions == [.transfert(
            produit: catheters.id, source: chezMoi.id, destination: parents.id, quantite: 3
        )])
    }

    @Test func usageSimple() {
        #expect(interpreter("J'ai utilisé 2 bandelettes") == [
            .usage(produit: bandelettes.id, lieu: nil, quantite: 2)
        ])
    }

    @Test func usageAvecLieu() {
        #expect(interpreter("j'ai utilisé une bandelette chez mes parents") == [
            .usage(produit: bandelettes.id, lieu: parents.id, quantite: 1)
        ])
    }

    @Test func questionDeStock() {
        #expect(interpreter("Combien il me reste de cathéters ?") == [.stock(produit: catheters.id)])
    }

    @Test func transfertVersSurMoiImplicite() {
        // « je prends … de chez moi » sans destination → le pochon (Sur moi).
        #expect(interpreter("Je prends 2 stylos depuis chez moi") == [.transfert(
            produit: stylos.id, source: chezMoi.id, destination: surMoi.id, quantite: 2
        )])
    }

    @Test func produitInconnuEstIncompris() {
        if case .incomprise = interpreter("j'ai utilisé 2 licornes").first {
            // attendu
        } else {
            Issue.record("Une phrase sans produit connu doit être incomprise")
        }
    }

    @Test func accentsEtMajusculesIgnores() {
        #expect(interpreter("J'AI UTILISÉ 2 CATHÉTERS") == [
            .usage(produit: catheters.id, lieu: nil, quantite: 2)
        ])
    }

    @Test func chezMoiNeMatchePasChezMesParents() {
        #expect(interpreter("je transfère 4 bandelettes de chez mes parents vers chez moi") == [.transfert(
            produit: bandelettes.id, source: parents.id, destination: chezMoi.id, quantite: 4
        )])
    }

    // MARK: - Fautes de frappe

    @Test func uneFauteDOrthographeEstToleree() {
        // « cathétres » (e manquant) et « bandellettes » (double l).
        #expect(interpreter("j'ai utilisé 2 cathétres") == [
            .usage(produit: catheters.id, lieu: nil, quantite: 2)
        ])
        #expect(interpreter("j'ai reçu 5 bandellettes chez moi") == [
            .reception(produit: bandelettes.id, lieu: chezMoi.id, quantite: 5)
        ])
    }

    @Test func deuxFautesSurUnMotLongPassent() {
        // « catétere » : h manquant + e final en trop = distance 2 sur 8 lettres.
        #expect(interpreter("j'ai pris 1 catétere") == [
            .usage(produit: catheters.id, lieu: nil, quantite: 1)
        ])
    }

    @Test func lesMotsCourtsRestentExacts() {
        // Pas de tolérance sous 4 lettres : « pmpe » ne doit pas matcher au hasard.
        if case .incomprise = interpreter("j'ai utilisé 2 pmp").first {
            // attendu
        } else {
            Issue.record("Un mot court trop différent ne doit pas matcher")
        }
    }

    @Test func leNomLePlusSpecifiqueGagne() {
        // « stylo insuline rapide » : le produit complet matche (3 mots),
        // « Pompes à insuline » ne doit pas voler le mot « insuline ».
        #expect(interpreter("j'ai utilisé 1 stylo insuline rapide") == [
            .usage(produit: stylos.id, lieu: nil, quantite: 1)
        ])
    }
}
