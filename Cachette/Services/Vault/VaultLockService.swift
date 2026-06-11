import Foundation
import LocalAuthentication

/// Verrou du coffre : Face ID / Touch ID avec repli code de l'appareil.
/// Re-verrouillé au passage en arrière-plan. Si l'appareil n'a aucun moyen
/// d'authentification, on n'enferme pas l'utilisateur dehors.
@Observable
final class VaultLockService {
    private(set) var estVerrouille = true

    func verrouiller() {
        estVerrouille = true
    }

    func deverrouiller() async {
        let contexte = LAContext()
        contexte.localizedReason = "Déverrouiller ton coffre à documents"

        var erreur: NSError?
        guard contexte.canEvaluatePolicy(.deviceOwnerAuthentication, error: &erreur) else {
            // Pas de Face ID ni de code configuré : le verrou n'a pas de sens.
            estVerrouille = false
            return
        }

        let reussi = (try? await contexte.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Déverrouiller ton coffre à documents"
        )) ?? false

        if reussi {
            estVerrouille = false
        }
    }
}
