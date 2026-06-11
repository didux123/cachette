import SwiftUI

/// Tuto interactif du premier lancement : l'écran s'assombrit, seule la zone
/// à toucher reste claire (et touchable), et on avance en faisant les VRAIS
/// gestes — créer un produit, ranger une boîte, en consommer une.

/// Les zones de l'inventaire que le tuto peut mettre en lumière.
nonisolated enum CibleTuto: Hashable {
    case ajouter   // bouton « ajouter un produit » de l'empty state
    case lieux     // les puces de lieux
    case ligne     // la première ligne produit (avec ses boutons + / −)
}

nonisolated struct CibleTutoKey: PreferenceKey {
    nonisolated static let defaultValue: [CibleTuto: Anchor<CGRect>] = [:]
    nonisolated static func reduce(
        value: inout [CibleTuto: Anchor<CGRect>],
        nextValue: () -> [CibleTuto: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func cibleTuto(_ cible: CibleTuto) -> some View {
        anchorPreference(key: CibleTutoKey.self, value: .bounds) { [cible: $0] }
    }
}

/// Les étapes, dans l'ordre. Celles à cible avancent quand le geste est fait ;
/// les autres ont un bouton.
enum EtapeTuto: Int, Comparable {
    case bienvenue
    case ajouterProduit
    case choisirLieu
    case recevoir
    case consommer
    case fin

    static func < (gauche: EtapeTuto, droite: EtapeTuto) -> Bool {
        gauche.rawValue < droite.rawValue
    }

    var cible: CibleTuto? {
        switch self {
        case .ajouterProduit: .ajouter
        case .choisirLieu: .lieux
        case .recevoir, .consommer: .ligne
        default: nil
        }
    }

    var titre: String {
        switch self {
        case .bienvenue: "On fait le tour ensemble ?"
        case .ajouterProduit: "Ton premier produit"
        case .choisirLieu: "Tes cachettes"
        case .recevoir: "Tu as reçu une boîte ?"
        case .consommer: "Tu en utilises un ?"
        case .fin: "Tu sais tout !"
        }
    }

    var message: String {
        switch self {
        case .bienvenue:
            "Je te montre les gestes essentiels en faisant pour de vrai — deux minutes, promis."
        case .ajouterProduit:
            "Touche le bouton éclairé pour créer ton premier produit à suivre."
        case .choisirLieu:
            "Voilà tes lieux de stockage. Touche « Chez moi » : c'est là qu'on va ranger."
        case .recevoir:
            "Appuie sur + pour ranger une unité ici. C'est LE geste du réassort."
        case .consommer:
            "Et − quand tu en utilises un — le stock et l'historique suivent tout seuls. Essaie !"
        case .fin:
            "En haut : ➕ pour les réassorts et nouveaux produits, 🚶 pour préparer un départ. En bas : Scanner les boîtes et ton Coffre à ordonnances. À toi de jouer !"
        }
    }

    /// Texte du bouton pour les étapes sans geste imposé.
    var bouton: String? {
        switch self {
        case .bienvenue: "C'est parti"
        case .fin: "Terminer"
        default: nil
        }
    }
}

/// L'overlay : 4 bandes sombres (qui avalent les touches) autour d'une
/// découpe claire, un anneau pulsé, et une carte d'explication.
struct TutorielOverlay: View {
    let etape: EtapeTuto
    /// Cadre de la cible dans le repère de l'overlay (nil = plein écran).
    let cadre: CGRect?
    let onBouton: () -> Void
    let onPasser: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private let voile = Color.black.opacity(0.68)
    private let marge: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let cadre {
                    let decoupe = cadre.insetBy(dx: -marge, dy: -marge)
                    bandes(autour: decoupe, dans: geo.size)
                    anneau(decoupe)
                    carte(taille: geo.size, decoupe: decoupe)
                } else {
                    voile.ignoresSafeArea()
                    carte(taille: geo.size, decoupe: nil)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: cadre)
        }
        .onAppear {
            if !reduceMotion { pulse = true }
        }
    }

    /// Le voile en 4 bandes : tout est bloqué SAUF la découpe, où les touches
    /// passent vers la vraie interface.
    @ViewBuilder
    private func bandes(autour decoupe: CGRect, dans taille: CGSize) -> some View {
        Group {
            voile
                .frame(width: taille.width, height: max(0, decoupe.minY))
                .position(x: taille.width / 2, y: max(0, decoupe.minY) / 2)
            voile
                .frame(width: taille.width, height: max(0, taille.height - decoupe.maxY))
                .position(x: taille.width / 2, y: decoupe.maxY + max(0, taille.height - decoupe.maxY) / 2)
            voile
                .frame(width: max(0, decoupe.minX), height: decoupe.height)
                .position(x: max(0, decoupe.minX) / 2, y: decoupe.midY)
            voile
                .frame(width: max(0, taille.width - decoupe.maxX), height: decoupe.height)
                .position(x: decoupe.maxX + max(0, taille.width - decoupe.maxX) / 2, y: decoupe.midY)
        }
        .ignoresSafeArea()
    }

    private func anneau(_ decoupe: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(CachetteColors.ambre, lineWidth: 3)
            .frame(width: decoupe.width, height: decoupe.height)
            .position(x: decoupe.midX, y: decoupe.midY)
            .scaleEffect(pulse ? 1.03 : 1.0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: pulse
            )
            .allowsHitTesting(false)
    }

    private func carte(taille: CGSize, decoupe: CGRect?) -> some View {
        // La carte se place dans la moitié opposée à la découpe.
        let enHaut = (decoupe?.midY ?? 0) > taille.height / 2

        return VStack(spacing: 12) {
            MascotteView(etat: .vigilante, taille: 64)
            Text(etape.titre)
                .font(CachetteTypography.titre)
                .foregroundStyle(CachetteColors.brunNoisette)
            Text(etape.message)
                .font(CachetteTypography.corps)
                .foregroundStyle(CachetteColors.brunNoisette)
                .multilineTextAlignment(.center)
            if let bouton = etape.bouton {
                Button {
                    onBouton()
                } label: {
                    Text(bouton).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(CachetteColors.rouxCachette)
            }
            Button("Passer le tuto") {
                onPasser()
            }
            .font(CachetteTypography.legende)
            .tint(CachetteColors.brunNoisette)
        }
        .padding(20)
        .background(CachetteColors.creme, in: .rect(cornerRadius: 20))
        .shadow(radius: 14)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: enHaut ? .top : .bottom)
        .padding(.vertical, 32)
    }
}
