import SwiftUI

/// Les états de la mascotte (brief DA §5). En MVP : sereine / vigilante /
/// alerte pilotés par les données, + contente / voyage / repos déclenchés
/// par les actions. Prêt à brancher sur une machine à états Rive (P1-4).
enum MascotteState: String, CaseIterable {
    case sereine
    case vigilante
    case alerte
    case contente
    case enVoyage
    case auRepos

    var nomAsset: String {
        switch self {
        case .sereine: "mascotte-sereine"
        case .vigilante: "mascotte-vigilante"
        case .alerte: "mascotte-alerte"
        case .contente: "mascotte-contente"
        case .enVoyage: "mascotte-voyage"
        case .auRepos: "mascotte-repos"
        }
    }

    /// Couleur d'ambiance (brief §5) — informe, n'alarme jamais.
    var couleurAmbiance: Color {
        switch self {
        case .sereine: CachetteColors.vertSauge
        case .vigilante: CachetteColors.ambre
        case .alerte: CachetteColors.terracotta
        case .contente: CachetteColors.rouxCachette
        case .enVoyage, .auRepos: CachetteColors.creme
        }
    }

    /// Message d'accompagnement, ton doux — jamais culpabilisant.
    var message: String {
        switch self {
        case .sereine: "Tout va bien, tes cachettes sont garnies."
        case .vigilante: "Je garde un œil sur une réserve qui baisse."
        case .alerte: "Une cachette mérite un réassort — rien d'urgent, on s'organise."
        case .contente: "Belle récolte ! Tes réserves sont à jour."
        case .enVoyage: "En route avec le pochon !"
        case .auRepos: "Tout est calme, je veille."
        }
    }
}
