import Foundation

enum VaultError: LocalizedError {
    case fichierIntrouvable

    var errorDescription: String? {
        switch self {
        case .fichierIntrouvable: "Ce document est introuvable dans le coffre."
        }
    }
}

/// Stockage des binaires du coffre (photos d'ordonnances, PDF) :
/// fichiers dans Application Support/Vault/, chiffrés par Data Protection
/// (`.completeFileProtection` : illisibles téléphone verrouillé), hors-ligne,
/// jamais dans SwiftData (seules les métadonnées y vivent).
struct VaultFileStore {
    private let dossier: URL

    init(dossier: URL = URL.applicationSupportDirectory.appending(path: "Vault", directoryHint: .isDirectory)) {
        self.dossier = dossier
    }

    /// Enregistre un binaire et renvoie le nom de fichier à stocker dans `DocumentItem`.
    func enregistrer(_ data: Data, extension ext: String) throws -> String {
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let nom = UUID().uuidString + "." + ext
        try data.write(to: url(pour: nom), options: [.atomic, .completeFileProtection])
        return nom
    }

    func url(pour nomFichier: String) -> URL {
        dossier.appending(path: nomFichier)
    }

    func lire(nomFichier: String) throws -> Data {
        let url = url(pour: nomFichier)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VaultError.fichierIntrouvable
        }
        return try Data(contentsOf: url)
    }

    func supprimer(nomFichier: String) {
        try? FileManager.default.removeItem(at: url(pour: nomFichier))
    }
}
