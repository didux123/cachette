import Foundation
import Testing
@testable import Cachette

struct BDPMRefreshServiceTests {
    private let cisTSV = """
    61266250\tDOLIPRANE 1000 mg, comprimé\tcomprimé\torale\tAutorisation active
    62170486\tAUTRE MEDICAMENT 50 mg, gélule\tgélule\torale\tAutorisation active
    99999999\tSANS CIP\tcomprimé\torale\tAutorisation active
    """

    private let cipTSV = """
    61266250\t3955838\tplaquette(s) thermoformée(s) PVC PVDC aluminium de 8 comprimé(s)\tPrésentation active\tCommercialisée\t12/03/2010\t3400935955838
    62170486\t1234567\tflacon(s) de 30 gélule(s)\tPrésentation active\tCommercialisée\t01/01/2020\t3400912345678
    61266250\t7654321\tlibellé sans nombre\tPrésentation active\tCommercialisée\t01/01/2020\tPASUNCIP13XXX
    """

    @Test func leParsingJointCISEtCIP() {
        let presentations = BDPMRefreshService.parsePresentations(cisTSV: cisTSV, cipTSV: cipTSV)

        #expect(presentations.count == 2) // la ligne au CIP13 invalide est ignorée
        let doliprane = presentations.first { $0.cip13 == "3400935955838" }
        #expect(doliprane?.denomination == "DOLIPRANE 1000 mg, comprimé")
        #expect(doliprane?.unitesParBoite == 8)
        #expect(doliprane?.etat == "Commercialisée")
    }

    @Test func extractionDesUnitesParBoite() {
        #expect(BDPMRefreshService.extraireUnites(libelle: "plaquette(s) de 30 comprimé(s)") == 30)
        #expect(BDPMRefreshService.extraireUnites(libelle: "5 stylo(s) prérempli(s) de 3 ml") == 5)
        #expect(BDPMRefreshService.extraireUnites(libelle: "boîte par 90 gélules") == 90)
        #expect(BDPMRefreshService.extraireUnites(libelle: "1 flacon(s) en verre de 60 ml") == 1)
        #expect(BDPMRefreshService.extraireUnites(libelle: "tube de crème") == nil)
    }

    @Test func laBaseGenereeEstLisibleParGRDB() throws {
        let presentations = BDPMRefreshService.parsePresentations(cisTSV: cisTSV, cipTSV: cipTSV)
        let url = FileManager.default.temporaryDirectory
            .appending(path: "bdpm-test-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        try BDPMRefreshService.ecrireBase(presentations: presentations, vers: url)

        // Relecture brute avec GRDB pour valider le schéma.
        let queue = try GRDBQueueLectureSeule(url: url)
        #expect(try queue.nombre() == 2)
        #expect(try queue.denomination(cip13: "3400912345678") == "AUTRE MEDICAMENT 50 mg, gélule")
    }

    @Test func decodageWindows1252() {
        let donnees = Data([0x47, 0xC9, 0x4C, 0x55, 0x4C, 0x45]) // "GÉLULE" en CP1252
        #expect(BDPMRefreshService.decoder(donnees) == "GÉLULE")
    }
}

/// Petit utilitaire de lecture pour le test (hors BDPMDatabase, qui pointe
/// sur le bundle / Application Support).
private struct GRDBQueueLectureSeule {
    let url: URL

    init(url: URL) throws {
        self.url = url
    }

    func nombre() throws -> Int {
        var configuration = GRDB.Configuration()
        configuration.readonly = true
        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        defer { try? queue.close() }
        return try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM presentation") ?? 0
        }
    }

    func denomination(cip13: String) throws -> String? {
        var configuration = GRDB.Configuration()
        configuration.readonly = true
        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        defer { try? queue.close() }
        return try queue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT denomination FROM presentation WHERE cip13 = ?",
                arguments: [cip13]
            )
        }
    }
}

import GRDB
