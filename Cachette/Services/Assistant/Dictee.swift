import Foundation
import AVFoundation
import Speech

/// Dictée vocale locale (SFSpeechRecognizer fr-FR) : micro → texte en direct.
/// La reconnaissance se fait sur l'appareil quand c'est supporté.
@Observable
final class Dictee {
    var transcription = ""
    var enEcoute = false
    var messageErreur: String?

    private var moteurAudio: AVAudioEngine?
    private var requete: SFSpeechAudioBufferRecognitionRequest?
    private var tache: SFSpeechRecognitionTask?
    private let reconnaisseur = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))

    func basculer() {
        if enEcoute {
            arreter()
        } else {
            Task { await demarrer() }
        }
    }

    func demarrer() async {
        let statut = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard statut == .authorized else {
            messageErreur = "Autorise la reconnaissance vocale dans Réglages > Cachette."
            return
        }
        let microOK = await AVAudioApplication.requestRecordPermission()
        guard microOK else {
            messageErreur = "Autorise le micro dans Réglages > Cachette."
            return
        }
        guard let reconnaisseur, reconnaisseur.isAvailable else {
            messageErreur = "La reconnaissance vocale n'est pas disponible sur cet appareil."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let moteur = AVAudioEngine()
            let requete = SFSpeechAudioBufferRecognitionRequest()
            requete.shouldReportPartialResults = true
            if reconnaisseur.supportsOnDeviceRecognition {
                requete.requiresOnDeviceRecognition = true
            }

            let entree = moteur.inputNode
            let format = entree.outputFormat(forBus: 0)
            entree.installTap(onBus: 0, bufferSize: 1024, format: format) { tampon, _ in
                requete.append(tampon)
            }
            moteur.prepare()
            try moteur.start()

            self.moteurAudio = moteur
            self.requete = requete
            self.transcription = ""
            self.enEcoute = true
            self.messageErreur = nil

            tache = reconnaisseur.recognitionTask(with: requete) { [weak self] resultat, erreur in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let resultat {
                        self.transcription = resultat.bestTranscription.formattedString
                    }
                    if erreur != nil || (resultat?.isFinal ?? false) {
                        self.arreter()
                    }
                }
            }
        } catch {
            messageErreur = "Impossible de démarrer le micro."
            arreter()
        }
    }

    func arreter() {
        moteurAudio?.stop()
        moteurAudio?.inputNode.removeTap(onBus: 0)
        requete?.endAudio()
        tache?.cancel()
        moteurAudio = nil
        requete = nil
        tache = nil
        enEcoute = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
