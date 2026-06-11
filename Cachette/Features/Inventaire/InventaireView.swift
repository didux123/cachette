import SwiftUI
import SwiftData
import TipKit

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

    private var produitsVisibles: [Produit] {
        guard let lieu = lieuSelectionne else { return produits }
        return produits.filter { $0.stock(dans: lieu) > 0 }
    }

    @AppStorage(ReglagesCles.fenetrePeremptionJours)
    private var fenetrePeremption = ReglagesCles.fenetrePeremptionDefaut

    private var etatMascotte: MascotteState {
        MascotteEngine.etat(produits: produits, fenetrePeremptionJours: fenetrePeremption)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MascotteBanner(etat: etatMascotte)
                    .padding(.top, 4)
                TipView(TipPucesLieux())
                    .padding(.horizontal)
                selecteurLieu
                if produitsVisibles.isEmpty {
                    emptyState
                } else {
                    listeProduits
                }
            }
            .background(CachetteColors.creme.opacity(0.5))
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
                    .popoverTip(TipJePars())
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
                    .popoverTip(TipAjouter())
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
        }
    }

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
            TipView(TipPlusMoins())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
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
            Text(produit.type.symbole)
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
                HStack(spacing: 0) {
                    Button(action: onMoins) {
                        Image(systemName: "minus")
                            .frame(width: 36, height: 32)
                    }
                    .disabled(quantite == 0)
                    Divider().frame(height: 18)
                    Button(action: onPlus) {
                        Image(systemName: "plus")
                            .frame(width: 36, height: 32)
                    }
                }
                .buttonStyle(.plain)
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
