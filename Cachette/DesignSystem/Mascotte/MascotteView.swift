import SwiftUI

/// La mascotte à l'écran : décorative et informative, jamais bloquante.
/// Micro-vie (respiration) coupée si Reduce Motion est activé.
struct MascotteView: View {
    let etat: MascotteState
    var taille: CGFloat = 96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var respire = false

    var body: some View {
        Image(etat.nomAsset)
            .resizable()
            .scaledToFit()
            .frame(width: taille, height: taille)
            .scaleEffect(respire ? 1.02 : 1.0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                value: respire
            )
            .onAppear {
                if !reduceMotion { respire = true }
            }
            .accessibilityLabel("Cachette, la mascotte — \(etat.message)")
    }
}

/// Bandeau d'accueil : mascotte + message d'état, sur fond d'ambiance.
struct MascotteBanner: View {
    let etat: MascotteState

    var body: some View {
        HStack(spacing: 12) {
            MascotteView(etat: etat, taille: 72)
            Text(etat.message)
                .font(CachetteTypography.corps)
                .foregroundStyle(CachetteColors.brunNoisette)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(etat.couleurAmbiance.opacity(0.16), in: .rect(cornerRadius: 16))
        .padding(.horizontal)
    }
}

/// Empty state porté par la mascotte.
struct MascotteEmptyState: View {
    var etat: MascotteState = .sereine
    let message: String
    var boutonTitre: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            MascotteView(etat: etat, taille: 140)
            Text(message)
                .font(CachetteTypography.corps)
                .foregroundStyle(CachetteColors.brunNoisette)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if let boutonTitre, let action {
                Button(boutonTitre, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(CachetteColors.rouxCachette)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
