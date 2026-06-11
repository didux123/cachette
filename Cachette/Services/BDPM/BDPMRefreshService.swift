import Foundation
import GRDB

/// Rafraîchissement du snapshot BDPM (~mensuel, fichiers TSV de quelques Mo) :
/// téléchargement → parsing → nouveau SQLite → swap atomique. En cas d'échec,
/// l'ancien snapshot (ou celui du bundle) reste en place : jamais de base cassée.
struct BDPMRefreshService: Sendable {
    static let identifiantTache = "com.didux.cachette.bdpmRefresh"
    /// Au-delà : refresh opportuniste au lancement (les BGTask ne sont jamais garanties).
    static let seuilOpportunisteJours = 45
    /// Au-delà : une BGTask est programmée.
    static let seuilProgrammationJours = 30

    nonisolated static let urlCIS = URL(string: "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_bdpm.txt")!
    nonisolated static let urlCIP = URL(string: "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_bdpm.txt")!

    nonisolated struct Presentation {
        let cip13: String
        let cis: String
        let denomination: String
        let libelle: String
        let etat: String
        let unitesParBoite: Int?
    }

    // MARK: - Orchestration

    /// Refresh uniquement si le snapshot actif est plus vieux que `seuilJours`.
    nonisolated func rafraichirSiPlusVieuxQue(_ seuilJours: Int) async -> Bool {
        guard let age = ageSnapshotJours(), age > seuilJours else { return false }
        do {
            try await rafraichir()
            return true
        } catch {
            // Échec réseau/parsing : on garde l'ancien snapshot, on réessaiera.
            return false
        }
    }

    nonisolated func ageSnapshotJours() -> Int? {
        guard let base = try? BDPMDatabase(), let date = try? base.dateSnapshot() else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: .now).day
    }

    nonisolated func rafraichir() async throws {
        let (dataCIS, _) = try await URLSession.shared.data(from: Self.urlCIS)
        let (dataCIP, _) = try await URLSession.shared.data(from: Self.urlCIP)

        let presentations = Self.parsePresentations(
            cisTSV: Self.decoder(dataCIS),
            cipTSV: Self.decoder(dataCIP)
        )
        // Garde-fou : un fichier tronqué/changé ne doit pas écraser une base saine.
        guard presentations.count > 10_000 else {
            throw URLError(.cannotParseResponse)
        }

        let urlTemporaire = FileManager.default.temporaryDirectory
            .appending(path: "bdpm_new-\(UUID().uuidString).sqlite")
        try Self.ecrireBase(presentations: presentations, vers: urlTemporaire)

        // Swap atomique vers Application Support (prioritaire sur le bundle).
        let destination = BDPMDatabase.urlApplicationSupport
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: urlTemporaire)
        } else {
            try FileManager.default.moveItem(at: urlTemporaire, to: destination)
        }
    }

    // MARK: - Parsing pur (testable, mêmes règles que Tools/bdpm_build.py)

    nonisolated static func decoder(_ data: Data) -> String {
        String(data: data, encoding: .windowsCP1252)
            ?? String(decoding: data, as: UTF8.self)
    }

    nonisolated static func parsePresentations(cisTSV: String, cipTSV: String) -> [Presentation] {
        // CIS_bdpm : 0=CIS, 1=dénomination
        var medicaments: [String: String] = [:]
        for ligne in cisTSV.split(separator: "\n", omittingEmptySubsequences: true) {
            let champs = ligne.split(separator: "\t", omittingEmptySubsequences: false)
            guard champs.count >= 2 else { continue }
            medicaments[champs[0].trimmingCharacters(in: .whitespaces)] =
                champs[1].trimmingCharacters(in: .whitespaces)
        }

        // CIS_CIP : 0=CIS, 2=libellé présentation, 4=état commercialisation, 6=CIP13
        var presentations: [Presentation] = []
        for ligne in cipTSV.split(separator: "\n", omittingEmptySubsequences: true) {
            let champs = ligne.split(separator: "\t", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard champs.count >= 7 else { continue }
            let cip13 = champs[6]
            guard cip13.count == 13, cip13.allSatisfy(\.isNumber),
                  let denomination = medicaments[champs[0]]
            else { continue }
            presentations.append(
                Presentation(
                    cip13: cip13,
                    cis: champs[0],
                    denomination: denomination,
                    libelle: champs[2],
                    etat: champs[4],
                    unitesParBoite: extraireUnites(libelle: champs[2])
                )
            )
        }
        return presentations
    }

    /// « boîte de 30 comprimés », « 5 stylos préremplis »… → plus grande
    /// quantité plausible trouvée (même règle que le script Python).
    nonisolated static func extraireUnites(libelle: String) -> Int? {
        let motif = /(?:de|par)?\s*(\d{1,4})\s*(comprim|g[ée]lule|capsule|sachet|ampoule|stylo|seringue|dose|film|ovule|suppositoire|cartouche|bande|compresse|unidose|implant|patch|r[ée]cipient|flacon)/
            .ignoresCase()
        let candidats = libelle.matches(of: motif)
            .compactMap { Int($0.1) }
            .filter { (1...1000).contains($0) }
        return candidats.max()
    }

    // MARK: - Écriture SQLite

    nonisolated static func ecrireBase(presentations: [Presentation], vers url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        let queue = try DatabaseQueue(path: url.path)
        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE presentation(
                    cip13 TEXT PRIMARY KEY,
                    cis TEXT NOT NULL,
                    denomination TEXT NOT NULL,
                    libelle_presentation TEXT,
                    etat_commercialisation TEXT,
                    unites_par_boite INTEGER
                );
                """)
            try db.execute(sql: "CREATE TABLE meta(cle TEXT PRIMARY KEY, valeur TEXT);")
            for presentation in presentations {
                try db.execute(
                    sql: "INSERT OR REPLACE INTO presentation VALUES (?,?,?,?,?,?)",
                    arguments: [
                        presentation.cip13, presentation.cis, presentation.denomination,
                        presentation.libelle, presentation.etat, presentation.unitesParBoite,
                    ]
                )
            }
            let dateISO = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
            try db.execute(sql: "INSERT INTO meta VALUES ('date_snapshot', ?)", arguments: [dateISO])
            try db.execute(sql: "INSERT INTO meta VALUES ('version_schema', '1')")
        }
        try queue.vacuum()
        try queue.close()
    }
}
