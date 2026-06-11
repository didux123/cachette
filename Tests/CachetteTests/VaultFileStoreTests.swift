import Foundation
import Testing
@testable import Cachette

nonisolated private let estSimulateur: Bool = {
    #if targetEnvironment(simulator)
    true
    #else
    false
    #endif
}()

struct VaultFileStoreTests {
    private func storeTemporaire() -> (VaultFileStore, URL) {
        let dossier = FileManager.default.temporaryDirectory
            .appending(path: "VaultTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        return (VaultFileStore(dossier: dossier), dossier)
    }

    @Test func ecritureLectureSuppresion() throws {
        let (store, dossier) = storeTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }

        let contenu = Data("ordonnance test".utf8)
        let nom = try store.enregistrer(contenu, extension: "pdf")

        #expect(nom.hasSuffix(".pdf"))
        #expect(try store.lire(nomFichier: nom) == contenu)

        store.supprimer(nomFichier: nom)
        #expect(throws: VaultError.self) {
            try store.lire(nomFichier: nom)
        }
    }

    /// Le simulateur n'applique pas Data Protection : ce test ne vaut que sur
    /// un vrai iPhone (à vérifier lors du test sur appareil, jalon M6).
    @Test(.enabled(if: !estSimulateur))
    func lesFichiersSontProtegesParDataProtection() throws {
        let (store, dossier) = storeTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }

        let nom = try store.enregistrer(Data("secret".utf8), extension: "jpg")
        let attributs = try FileManager.default.attributesOfItem(atPath: store.url(pour: nom).path)
        let protection = attributs[.protectionKey] as? FileProtectionType

        #expect(protection == .complete)
    }

    @Test func deuxEnregistrementsDonnentDesNomsUniques() throws {
        let (store, dossier) = storeTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }

        let nom1 = try store.enregistrer(Data("a".utf8), extension: "jpg")
        let nom2 = try store.enregistrer(Data("b".utf8), extension: "jpg")
        #expect(nom1 != nom2)
    }
}
