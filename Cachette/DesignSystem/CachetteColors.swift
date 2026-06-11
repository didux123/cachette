import SwiftUI

/// Tokens de couleur du brief de direction artistique (§4).
enum CachetteColors {
    /// Pelage de la mascotte, couleur d'accent de la marque.
    static let rouxCachette = Color(hex: 0xC8643C)
    /// Fonds doux.
    static let creme = Color(hex: 0xF6EFE3)
    /// État serein / OK.
    static let vertSauge = Color(hex: 0x7FA67E)
    /// État vigilant.
    static let ambre = Color(hex: 0xE2A33C)
    /// État alerte — chaud mais jamais rouge agressif.
    static let terracotta = Color(hex: 0xD2705B)
    /// Textes et contours.
    static let brunNoisette = Color(hex: 0x5B4636)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
