import SwiftUI

/// Fond commun à toutes les pages : dégradé crème chaleureux, avec en option
/// la mascotte qui se glisse discrètement dans un coin.
private struct FondCachetteModifier: ViewModifier {
    var mascotte: MascotteState?
    var alignement: Alignment

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background {
                ZStack(alignment: alignement) {
                    LinearGradient(
                        colors: [CachetteColors.creme, Color(hex: 0xF0E2CE)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    if let mascotte {
                        Image(mascotte.nomAsset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 92)
                            .opacity(0.45)
                            .rotationEffect(.degrees(alignement == .bottomLeading ? -7 : 7))
                            .padding(18)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    /// Applique le fond Cachette ; passe un état de mascotte pour qu'elle
    /// apparaisse en filigrane dans un coin de la page.
    func fondCachette(
        mascotte: MascotteState? = nil,
        alignement: Alignment = .bottomTrailing
    ) -> some View {
        modifier(FondCachetteModifier(mascotte: mascotte, alignement: alignement))
    }
}
