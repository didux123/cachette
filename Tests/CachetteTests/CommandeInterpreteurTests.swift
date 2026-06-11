import Foundation
import Testing
@testable import Cachette

struct CommandeInterpreteurTests {
    // Référentiel type : 3 produits, 3 lieux dont « Sur moi ».
    private let catheters = ProduitRef(id: UUID(), nom: "Cathéters de pompe")
    private let bandelettes = ProduitRef(id: UUID(), nom: "Bandelettes")
    private let stylos = ProduitRef(id: UUID(), nom: "Stylo insuline rapide")

    private let chezMoi = LieuRef(id: UUID(), nom: "Chez moi", estSurMoi: false)
    private let parents = LieuRef(id: UUID(), nom: "Chez mes parents", estSurMoi: false)
    private let surMoi = LieuRef(id: UUID(), nom: "Sur moi", estSurMoi: true)

    private var produits: [ProduitRef] { [catheters, bandelettes, stylos] }
    private var lieux: [LieuRef] { [chezMoi, parents, surMoi] }

    private func interpreter(_ phrase: String) -> IntentionAssistant {
        CommandeInterpreteur.interpreter(phrase, produits: produits, lieux: lieux)
    }

    @Test func laPhraseExempleDeMaxence() {
        let intention = interpreter("Je prends 3 cathéters de chez moi pour aller chez mes parents")
        #expect(intention == .transfert(
            produit: catheters.id, source: chezMoi.id, destination: parents.id, quantite: 3
        ))
    }

    @Test func usageSimple() {
        let intention = interpreter("J'ai utilisé 2 bandelettes")
        #expect(intention == .usage(produit: bandelettes.id, lieu: nil, quantite: 2))
    }

    @Test func usageAvecLieu() {
        let intention = interpreter("j'ai utilisé une bandelette chez mes parents")
        #expect(intention == .usage(produit: bandelettes.id, lieu: parents.id, quantite: 1))
    }

    @Test func receptionAvecLieu() {
        let intention = interpreter("J'ai reçu 5 stylos d'insuline rapide chez moi")
        #expect(intention == .reception(produit: stylos.id, lieu: chezMoi.id, quantite: 5))
    }

    @Test func questionDeStock() {
        let intention = interpreter("Combien il me reste de cathéters ?")
        #expect(intention == .stock(produit: catheters.id))
    }

    @Test func transfertVersSurMoiImplicite() {
        // « je prends … de chez moi » sans destination → le pochon (Sur moi).
        let intention = interpreter("Je prends 2 stylos depuis chez moi")
        #expect(intention == .transfert(
            produit: stylos.id, source: chezMoi.id, destination: surMoi.id, quantite: 2
        ))
    }

    @Test func nombreEnLettres() {
        let intention = interpreter("j'ai utilisé trois bandelettes")
        #expect(intention == .usage(produit: bandelettes.id, lieu: nil, quantite: 3))
    }

    @Test func quantiteParDefautUn() {
        let intention = interpreter("j'ai utilisé un cathéter")
        #expect(intention == .usage(produit: catheters.id, lieu: nil, quantite: 1))
    }

    @Test func produitInconnuEstIncompris() {
        if case .incomprise = interpreter("j'ai utilisé 2 licornes") {
            // attendu
        } else {
            Issue.record("Une phrase sans produit connu doit être incomprise")
        }
    }

    @Test func accentsEtMajusculesIgnores() {
        let intention = interpreter("J'AI UTILISÉ 2 CATHÉTERS")
        #expect(intention == .usage(produit: catheters.id, lieu: nil, quantite: 2))
    }

    @Test func chezMoiNeMatchePasChezMesParents() {
        // Vérifie que les deux lieux distincts sont bien attribués source/destination.
        let intention = interpreter("je transfère 4 bandelettes de chez mes parents vers chez moi")
        #expect(intention == .transfert(
            produit: bandelettes.id, source: parents.id, destination: chezMoi.id, quantite: 4
        ))
    }
}
