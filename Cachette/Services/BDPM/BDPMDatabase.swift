import Foundation
import GRDB

nonisolated struct BDPMPresentation: Equatable {
    let cip13: String
    let cis: String
    let denomination: String
    let libellePresentation: String?
    let etatCommercialisation: String?
    let unitesParBoite: Int?
}

enum BDPMError: LocalizedError {
    case baseIntrouvable

    var errorDescription: String? {
        switch self {
        case .baseIntrouvable: "La base médicaments est introuvable dans l'app."
        }
    }
}

/// Accès en lecture seule à la base BDPM (résolution CIP13 → médicament, hors-ligne).
/// Priorité au snapshot rafraîchi dans Application Support (M9), sinon celui du bundle.
final class BDPMDatabase: Sendable {
    private let queue: DatabaseQueue

    nonisolated static let nomFichier = "bdpm.sqlite"

    /// Emplacement du snapshot rafraîchi par la tâche de fond.
    nonisolated static var urlApplicationSupport: URL {
        URL.applicationSupportDirectory.appending(path: nomFichier)
    }

    init() throws {
        let fm = FileManager.default
        let chemin: String
        if fm.fileExists(atPath: Self.urlApplicationSupport.path) {
            chemin = Self.urlApplicationSupport.path
        } else if let bundle = Bundle.main.url(forResource: "bdpm", withExtension: "sqlite") {
            chemin = bundle.path
        } else {
            throw BDPMError.baseIntrouvable
        }

        var configuration = Configuration()
        configuration.readonly = true
        queue = try DatabaseQueue(path: chemin, configuration: configuration)
    }

    nonisolated func presentation(cip13: String) throws -> BDPMPresentation? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM presentation WHERE cip13 = ?",
                arguments: [cip13]
            ) else { return nil }
            return BDPMPresentation(
                cip13: row["cip13"],
                cis: row["cis"],
                denomination: row["denomination"],
                libellePresentation: row["libelle_presentation"],
                etatCommercialisation: row["etat_commercialisation"],
                unitesParBoite: row["unites_par_boite"]
            )
        }
    }

    nonisolated func nombreDePresentations() throws -> Int {
        try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM presentation") ?? 0
        }
    }

    nonisolated func dateSnapshot() throws -> Date? {
        try queue.read { db in
            guard let valeur = try String.fetchOne(
                db,
                sql: "SELECT valeur FROM meta WHERE cle = 'date_snapshot'"
            ) else { return nil }
            return ISO8601DateFormatter().date(from: valeur + "T00:00:00Z")
        }
    }
}
