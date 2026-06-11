import SwiftUI

/// Tuto interactif du premier lancement : l'écran s'assombrit, seule la zone
/// à toucher reste claire (et touchable), une petite main invite au geste,
/// et on avance en faisant les VRAIS gestes sur de vraies données.

/// Les zones de l'inventaire que le tuto met en lumière.
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

extension Notification.Name {
    static let cachetteFicheProduitOuverte = Notification.Name("cachetteFicheProduitOuverte")
    static let cachetteFicheProduitFermee = Notification.Name("cachetteFicheProduitFermee")
}

/// Les étapes du parcours. Celles à cible avancent quand le geste est fait ;
/// les autres ont un bouton.
enum EtapeTuto: Int, CaseIterable {
    case bienvenue
    case ajouterProduit // seulement si la liste est vide
    case choisirLieu
    case recevoir
    case consommer
    case ouvrirFiche
    case fin

    var cible: CibleTuto? {
        switch self {
        case .ajouterProduit: .ajouter
        case .choisirLieu: .lieux
        case .recevoir, .consommer, .ouvrirFiche: .ligne
        default: nil
        }
    }

    var mascotte: MascotteState {
        switch self {
        case .bienvenue: .contente
        case .ajouterProduit, .choisirLieu: .vigilante
        case .recevoir: .contente
        case .consommer: .sereine
        case .ouvrirFiche: .vigilante
        case .fin: .enVoyage
        }
    }

    var titre: String {
        switch self {
        case .bienvenue: "Je te fais visiter ?"
        case .ajouterProduit: "Ton premier produit"
        case .choisirLieu: "Tes cachettes"
        case .recevoir: "Range une boîte"
        case .consommer: "Et quand tu en utilises…"
        case .ouvrirFiche: "La fiche complète"
        case .fin: "À toi de jouer !"
        }
    }

    var message: String {
        switch self {
        case .bienvenue:
            "Deux minutes, en faisant les vrais gestes. C'est parti ?"
        case .ajouterProduit:
            "Touche le bouton éclairé pour créer ton premier produit à suivre."
        case .choisirLieu:
            "Chaque puce est un lieu de stockage. Touche 🏠 Chez moi."
        case .recevoir:
            "Je t'ai déjà rangé 3 unités pour essayer 😉. Touche + : tu viens d'en recevoir une !"
        case .consommer:
            "Touche − : une unité utilisée. Le stock et l'historique suivent tout seuls."
        case .ouvrirFiche:
            "Touche la ligne : lots, péremptions, historique, transferts… tout y est. Reviens quand tu as vu !"
        case .fin:
            "En haut : ➕ réassorts et nouveaux produits, 🚶 préparer un départ.\nEn bas : 🎙️ l'assistant pour tout gérer à la voix, 🔒 ton coffre à ordonnances."
        }
    }

    var bouton: String? {
        switch self {
        case .bienvenue: "C'est parti !"
        case .fin: "Terminer la visite"
        default: nil
        }
    }
}

// MARK: - Overlay

/// Voile sombre à découpe arrondie (even-odd), bloqueurs de touches autour de
/// la cible, anneau lumineux pulsé, main animée, carte à ressort avec
/// progression.
struct TutorielOverlay: View {
    let etape: EtapeTuto
    let flux: [EtapeTuto]
    /// Cadre de la cible dans le repère plein écran (nil = plein voile).
    let cadre: CGRect?
    let onBouton: () -> Void
    /// Saute uniquement l'étape courante (filet de secours : le tuto ne doit
    /// JAMAIS pouvoir coincer l'utilisateur).
    let onPasserEtape: () -> Void
    let onPasser: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var apparition = false

    private let marge: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let decoupe = cadre?.insetBy(dx: -marge, dy: -marge)
            ZStack {
                masque(decoupe: decoupe, taille: geo.size)
                if let decoupe {
                    bloqueurs(autour: decoupe, dans: geo.size)
                    anneau(decoupe)
                    main(decoupe, taille: geo.size)
                } else {
                    // Plein voile : tout est bloqué sauf la carte.
                    Color.white.opacity(0.001)
                        .contentShape(Rectangle())
                }
                carte(taille: geo.size, decoupe: decoupe)
            }
            .animation(.spring(duration: 0.45), value: cadre)
        }
        .ignoresSafeArea()
        .onAppear {
            apparition = true
            if !reduceMotion { pulse = true }
        }
    }

    /// Le voile : un seul Path even-odd → découpe aux coins arrondis, propre.
    private func masque(decoupe: CGRect?, taille: CGSize) -> some View {
        var chemin = Path()
        chemin.addRect(CGRect(origin: .zero, size: taille))
        if let decoupe {
            chemin.addRoundedRect(in: decoupe, cornerSize: CGSize(width: 16, height: 16))
        }
        return chemin
            .fill(Color.black.opacity(0.72), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)
    }

    /// 4 zones invisibles qui avalent les touches PARTOUT sauf la découpe.
    /// ⚠️ Le `contentShape` doit être posé AVANT `.position` : le conteneur
    /// créé par `.position` occupe tout l'écran, et un contentShape posé
    /// après rendrait chaque bande tactile sur TOUT l'écran (trou bouché).
    @ViewBuilder
    private func bloqueurs(autour decoupe: CGRect, dans taille: CGSize) -> some View {
        bande(largeur: taille.width, hauteur: max(0, decoupe.minY))
            .position(x: taille.width / 2, y: max(0, decoupe.minY) / 2)
        bande(largeur: taille.width, hauteur: max(0, taille.height - decoupe.maxY))
            .position(x: taille.width / 2, y: decoupe.maxY + max(0, taille.height - decoupe.maxY) / 2)
        bande(largeur: max(0, decoupe.minX), hauteur: decoupe.height)
            .position(x: max(0, decoupe.minX) / 2, y: decoupe.midY)
        bande(largeur: max(0, taille.width - decoupe.maxX), hauteur: decoupe.height)
            .position(x: decoupe.maxX + max(0, taille.width - decoupe.maxX) / 2, y: decoupe.midY)
    }

    private func bande(largeur: CGFloat, hauteur: CGFloat) -> some View {
        Color.white.opacity(0.001)
            .frame(width: max(0, largeur), height: max(0, hauteur))
            .contentShape(Rectangle())
    }

    private func anneau(_ decoupe: CGRect) -> some View {
        // Ombre fixe (animer un rayon d'ombre coûte cher) ; seul le scale pulse.
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(CachetteColors.ambre, lineWidth: 3)
            .shadow(color: CachetteColors.ambre.opacity(0.7), radius: 9)
            .frame(width: decoupe.width, height: decoupe.height)
            .scaleEffect(pulse ? 1.03 : 1.0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.85).repeatForever(autoreverses: true),
                value: pulse
            )
            .position(x: decoupe.midX, y: decoupe.midY)
            .allowsHitTesting(false)
    }

    /// La petite main qui invite à toucher, qui rebondit vers la cible.
    private func main(_ decoupe: CGRect, taille: CGSize) -> some View {
        let cibleEnHaut = decoupe.midY < taille.height / 2
        return Text(cibleEnHaut ? "👆" : "👇")
            .font(.system(size: 38))
            .position(
                x: decoupe.midX,
                y: cibleEnHaut ? decoupe.maxY + 34 : decoupe.minY - 34
            )
            .offset(y: pulse ? (cibleEnHaut ? -8 : 8) : 0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                value: pulse
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func carte(taille: CGSize, decoupe: CGRect?) -> some View {
        // La carte se place dans la moitié opposée à la découpe.
        let cibleEnHaut = (decoupe?.midY ?? 0) < taille.height / 2
        let index = flux.firstIndex(of: etape) ?? 0
        // Cible attendue mais introuvable : on offre une sortie franche.
        let cibleIntrouvable = etape.cible != nil && decoupe == nil

        return VStack(spacing: 12) {
            MascotteView(etat: etape.mascotte, taille: 70)
            Text(etape.titre)
                .font(CachetteTypography.titre)
                .foregroundStyle(CachetteColors.brunNoisette)
            Text(etape.message)
                .font(CachetteTypography.corps)
                .foregroundStyle(CachetteColors.brunNoisette)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Points de progression.
            HStack(spacing: 6) {
                ForEach(Array(flux.enumerated()), id: \.offset) { i, _ in
                    Circle()
                        .fill(i <= index ? CachetteColors.rouxCachette : CachetteColors.brunNoisette.opacity(0.18))
                        .frame(width: i == index ? 9 : 6, height: i == index ? 9 : 6)
                }
            }
            .animation(.spring(duration: 0.3), value: index)

            if let bouton = etape.bouton {
                Button {
                    onBouton()
                } label: {
                    Text(bouton).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(CachetteColors.rouxCachette)
            } else if cibleIntrouvable {
                Button {
                    onPasserEtape()
                } label: {
                    Text("Continuer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(CachetteColors.rouxCachette)
            }

            HStack(spacing: 18) {
                if etape.cible != nil, !cibleIntrouvable {
                    Button("Passer cette étape") {
                        onPasserEtape()
                    }
                }
                Button("Quitter la visite") {
                    onPasser()
                }
            }
            .font(CachetteTypography.legende)
            .tint(CachetteColors.brunNoisette.opacity(0.7))
        }
        .padding(22)
        .background(CachetteColors.creme, in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(CachetteColors.rouxCachette.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: 18, y: 6)
        .padding(.horizontal, 26)
        .scaleEffect(apparition ? 1 : 0.86)
        .opacity(apparition ? 1 : 0)
        .animation(.spring(duration: 0.4, bounce: 0.35), value: apparition)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: cibleEnHaut ? .bottom : .top
        )
        // L'overlay ignore les safe areas : la marge basse doit passer
        // au-dessus de la barre d'onglets (~83 pt avec l'indicateur home).
        .padding(.top, 64)
        .padding(.bottom, 112)
    }
}
