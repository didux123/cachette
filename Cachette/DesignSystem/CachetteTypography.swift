import SwiftUI

/// Typographie : sans-serif ronde et chaleureuse (brief §4).
/// On utilise le design `.rounded` du système — proche de Quicksand/Nunito,
/// gratuit, et compatible Dynamic Type d'office.
enum CachetteTypography {
    static let grandTitre = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let titre = Font.system(.title2, design: .rounded).weight(.semibold)
    static let corps = Font.system(.body, design: .rounded)
    static let legende = Font.system(.caption, design: .rounded)
}
