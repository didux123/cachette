import CoreGraphics
import Vision

/// Abstraction de l'OCR : image → lignes de texte.
/// Implémentation par défaut : Apple Vision (local, hors-ligne, gratuit).
/// En P1, cette interface accueillera Foundation Models et les fournisseurs
/// en ligne (Gemini / Mistral / OpenAI, clé en Keychain) sans refactor.
protocol OCRProvider: Sendable {
    func lignesDeTexte(dans image: CGImage) async throws -> [String]
}

struct VisionOCRProvider: OCRProvider {
    nonisolated func lignesDeTexte(dans image: CGImage) async throws -> [String] {
        var requete = RecognizeTextRequest()
        requete.recognitionLevel = .accurate
        requete.recognitionLanguages = [Locale.Language(identifier: "fr-FR")]
        // Les dates « 08/2027 » ne sont pas des mots : la correction
        // linguistique ferait plus de mal que de bien.
        requete.usesLanguageCorrection = false

        let observations = try await requete.perform(on: image)
        return observations.compactMap { $0.topCandidates(1).first?.string }
    }
}
