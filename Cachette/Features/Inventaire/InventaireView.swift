import SwiftUI
import SwiftData

/// Onglet « Réserves » : le stock, par lieu ou en vue totale.
struct InventaireView: View {
    @Environment(\.modelContext) private var contexte
    @Query(sort: \Lieu.ordre) private var lieux: [Lieu]
    @Query(sort: \Produit.nom) private var produits: [Produit]

    /// nil = vue « Total » (somme de tous les lieux).
    @State private var lieuSelectionne: Lieu?
    @State private var creationProduitPresentee = false
    @State private var historiquePresente = false
    @State private var jeParsPresente = false
    @State private var reassortPresente = false
    /// Produit fraîchement créé : on propose aussitôt d'en ranger le stock.
    @State private var produitPourRangement: Produit?
    @State private var messageErreur: String?

    // Tuto interactif du premier lancement.
    @AppStorage("tutorielTermine") private var tutorielTermine = false
    @State private var etapeTuto: EtapeTuto?
    @State private var baselineReceptions = 0
    @State private var baselineUsages = 0
    /// La fiche produit est ouverte : on suspend l'overlay du tuto.
    @State private var ficheOuverte = false
    /// Les étapes effectivement jouées (l'étape création saute si la liste
    /// de l'onboarding n'est pas vide).
    @State private var fluxTuto: [EtapeTuto] = []

    /// Vue « Total » : tous les produits suivis. Vue par lieu : tous aussi
    /// (même à 0 ici), pour que le réassort se fasse d'un + sur la ligne.
    private var produitsVisibles: [Produit] {
        guard let lieu = lieuSelectionne else { return produits }
        return produits.sorted {
            ($0.stock(dans: lieu) > 0 ? 0 : 1, $0.nom) < ($1.stock(dans: lieu) > 0 ? 0 : 1, $1.nom)
        }
    }

    @AppStorage(ReglagesCles.fenetrePeremptionJours)
    private var fenetrePeremption = ReglagesCles.fenetrePeremptionDefaut

    private var etatMascotte: MascotteState {
        MascotteEngine.etat(produits: produits, fenetrePeremptionJours: fenetrePeremption)
    }

    private var nbReceptions: Int {
        produits.flatMap(\.mouvements).count(where: { $0.motif == .reception })
    }

    private var nbUsages: Int {
        produits.flatMap(\.mouvements).count(where: { $0.motif == .usage })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MascotteBanner(etat: etatMascotte)
                    .padding(.top, 4)
                selecteurLieu
                    .cibleTuto(.lieux)
                if produitsVisibles.isEmpty {
                    emptyState
                } else {
                    listeProduits
                }
            }
            .fondCachette()
            .navigationTitle(lieuSelectionne?.nom ?? "Toutes mes réserves")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        LieuxListView()
                    } label: {
                        Label("Mes lieux", systemImage: "map")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        historiquePresente = true
                    } label: {
                        Label("Historique", systemImage: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        jeParsPresente = true
                    } label: {
                        Label("Je pars…", systemImage: "figure.walk.departure")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            reassortPresente = true
                        } label: {
                            Label("J'ai reçu (réassort)", systemImage: "shippingbox.and.arrow.backward")
                        }
                        Button {
                            creationProduitPresentee = true
                        } label: {
                            Label("Nouveau produit à suivre", systemImage: "plus.square.on.square")
                        }
                    } label: {
                        Label("Ajouter", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $jeParsPresente) {
                JeParsView()
            }
            .sheet(isPresented: $reassortPresente) {
                ReassortSheet()
            }
            .sheet(isPresented: $creationProduitPresentee) {
                ProduitFormView { produit in
                    produitPourRangement = produit
                }
            }
            .sheet(item: $produitPourRangement) { produit in
                AjoutStockSheetView(produit: produit)
            }
            .sheet(isPresented: $historiquePresente) {
                HistoriqueView()
            }
            .alert("Oups", isPresented: .init(
                get: { messageErreur != nil },
                set: { if !$0 { messageErreur = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(messageErreur ?? "")
            }
            .overlayPreferenceValue(CibleTutoKey.self) { ancres in
                if let etape = etapeTuto, !ficheOuverte {
                    GeometryReader { proxy in
                        TutorielOverlay(
                            etape: etape,
                            flux: fluxTuto,
                            cadre: etape.cible.flatMap { cible in
                                ancres[cible].map { ancre in
                                    var cadre = proxy[ancre]
                                    // L'ancre « ligne » est posée sur la List entière
                                    // (les préférences ne remontent pas depuis ses
                                    // cellules) : on n'éclaire que la première ligne.
                                    if cible == .ligne {
                                        cadre.size.height = min(cadre.height, 96)
                                    }
                                    return cadre
                                }
                            },
                            onBouton: { avancerTuto(depuis: etape) },
                            onPasserEtape: { passerEtape(etape) },
                            onPasser: { terminerTuto() }
                        )
                    }
                    .ignoresSafeArea()
                }
            }
            .onAppear { demarrerTutoSiNecessaire() }
            .onChange(of: produits.count) { _, _ in
                if etapeTuto == .ajouterProduit, !produits.isEmpty {
                    avancerTuto(depuis: .ajouterProduit)
                }
            }
            .onChange(of: lieuSelectionne) { _, nouveau in
                if etapeTuto == .choisirLieu, nouveau != nil {
                    avancerTuto(depuis: .choisirLieu)
                }
            }
            .onChange(of: nbReceptions) { _, nouveau in
                if etapeTuto == .recevoir, nouveau > baselineReceptions {
                    avancerTuto(depuis: .recevoir)
                }
            }
            .onChange(of: nbUsages) { _, nouveau in
                if etapeTuto == .consommer, nouveau > baselineUsages {
                    avancerTuto(depuis: .consommer)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .cachetteFicheProduitOuverte)) { _ in
                ficheOuverte = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .cachetteFicheProduitFermee)) { _ in
                ficheOuverte = false
                if etapeTuto == .ouvrirFiche {
                    avancerTuto(depuis: .ouvrirFiche)
                }
            }
        }
    }

    // MARK: - Tuto

    private func demarrerTutoSiNecessaire() {
        guard !tutorielTermine, etapeTuto == nil else { return }
        fluxTuto = produits.isEmpty
            ? [.bienvenue, .ajouterProduit, .choisirLieu, .recevoir, .consommer, .ouvrirFiche, .fin]
            : [.bienvenue, .choisirLieu, .recevoir, .consommer, .ouvrirFiche, .fin]
        baselineReceptions = nbReceptions
        baselineUsages = nbUsages
        etapeTuto = .bienvenue
    }

    private func avancerTuto(depuis etape: EtapeTuto) {
        guard let index = fluxTuto.firstIndex(of: etape), index + 1 < fluxTuto.count else {
            terminerTuto()
            return
        }
        let suivante = fluxTuto[index + 1]

        // Préparations propres à certaines étapes.
        switch suivante {
        case .recevoir:
            injecterStockDEssaiSiBesoin()
            baselineReceptions = nbReceptions
        case .consommer:
            baselineUsages = nbUsages
        default:
            break
        }
        etapeTuto = suivante
    }

    /// Pour que +/− aient du sens dès le tuto : on range 3 unités d'essai du
    /// premier produit dans le lieu choisi s'il est vide (motif « ajustement »,
    /// visible et assumé dans l'historique).
    private func injecterStockDEssaiSiBesoin() {
        guard let lieu = lieuSelectionne,
              let premier = produitsVisibles.first,
              premier.stock(dans: lieu) == 0
        else { return }
        try? StockService(contexte: contexte)
            .ajouterStock(produit: premier, lieu: lieu, quantite: 3, motif: .ajustement)
    }

    /// Saute UNE étape (filet de secours) en préparant l'état attendu pour la suite.
    private func passerEtape(_ etape: EtapeTuto) {
        if etape == .choisirLieu, lieuSelectionne == nil {
            // Sélectionner le lieu déclenche l'avancement via onChange.
            lieuSelectionne = lieux.first
            return
        }
        avancerTuto(depuis: etape)
    }

    private func terminerTuto() {
        tutorielTermine = true
        etapeTuto = nil
    }

    // MARK: - Sous-vues

    private var selecteurLieu: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PuceLieu(titre: "Total", emoji: "🌰", estActive: lieuSelectionne == nil) {
                    lieuSelectionne = nil
                }
                ForEach(lieux) { lieu in
                    PuceLieu(titre: lieu.nom, emoji: lieu.emoji, estActive: lieuSelectionne?.id == lieu.id) {
                        lieuSelectionne = lieu
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var listeProduits: some View {
        List {
            ForEach(produitsVisibles) { produit in
                NavigationLink {
                    ProduitDetailView(produit: produit)
                } label: {
                    ProduitRow(
                        produit: produit,
                        lieu: lieuSelectionne,
                        onMoins: lieuSelectionne.map { lieu in { retirer(produit, de: lieu) } },
                        onPlus: lieuSelectionne.map { lieu in { ajouter(produit, dans: lieu) } }
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
        .cibleTuto(.ligne)
    }

    private var emptyState: some View {
        MascotteEmptyState(
            message: lieuSelectionne == nil
                ? "Aucune réserve pour l'instant.\nOn ajoute ton premier produit ?"
                : "Rien dans cette cachette pour l'instant.",
            boutonTitre: "Ajouter un produit"
        ) {
            creationProduitPresentee = true
        }
        .cibleTuto(.ajouter)
    }

    private func retirer(_ produit: Produit, de lieu: Lieu) {
        do {
            try StockService(contexte: contexte).retirerStock(produit: produit, lieu: lieu, quantite: 1, motif: .usage)
        } catch {
            messageErreur = error.localizedDescription
        }
    }

    private func ajouter(_ produit: Produit, dans lieu: Lieu) {
        do {
            try StockService(contexte: contexte).ajouterStock(produit: produit, lieu: lieu, quantite: 1, motif: .reception)
        } catch {
            messageErreur = error.localizedDescription
        }
    }
}

private struct PuceLieu: View {
    let titre: String
    let emoji: String
    let estActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji)
                Text(titre)
                    .font(CachetteTypography.legende.weight(estActive ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                estActive ? CachetteColors.rouxCachette.opacity(0.18) : Color(.secondarySystemBackground),
                in: .capsule
            )
            .overlay {
                if estActive {
                    Capsule().strokeBorder(CachetteColors.rouxCachette, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(CachetteColors.brunNoisette)
        .accessibilityLabel(titre)
    }
}

private struct ProduitRow: View {
    let produit: Produit
    let lieu: Lieu?
    let onMoins: (() -> Void)?
    let onPlus: (() -> Void)?

    private var quantite: Int {
        lieu.map { produit.stock(dans: $0) } ?? produit.stockTotal
    }

    private var sousSeuil: Bool {
        guard let seuil = produit.seuilStockBas else { return false }
        return produit.stockTotal <= seuil
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(produit.symbole)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(produit.nom)
                    .font(CachetteTypography.corps.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(quantite)")
                        .font(CachetteTypography.legende.weight(.bold))
                        .foregroundStyle(sousSeuil ? CachetteColors.terracotta : CachetteColors.vertSauge)
                    Text(lieu == nil ? "au total" : "ici")
                        .font(CachetteTypography.legende)
                        .foregroundStyle(.secondary)
                    if sousSeuil {
                        Text("· stock bas")
                            .font(CachetteTypography.legende)
                            .foregroundStyle(CachetteColors.terracotta)
                    }
                }
            }
            Spacer()
            if let onMoins, let onPlus {
                // `.borderless` (et non `.plain`) : dans une ligne NavigationLink,
                // c'est ce qui empêche la ligne d'avaler le tap des boutons.
                HStack(spacing: 0) {
                    Button(action: onMoins) {
                        Image(systemName: "minus")
                            .frame(width: 40, height: 36)
                            .contentShape(Rectangle())
                    }
                    .disabled(quantite == 0)
                    .accessibilityLabel("Utiliser une unité")
                    Divider().frame(height: 18)
                    Button(action: onPlus) {
                        Image(systemName: "plus")
                            .frame(width: 40, height: 36)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Ranger une unité")
                }
                .buttonStyle(.borderless)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 8))
                .foregroundStyle(CachetteColors.rouxCachette)
            }
        }
    }
}

#Preview {
    InventaireView()
        .modelContainer(ModelContainerFactory.inMemory())
}
