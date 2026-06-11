import SwiftUI
import SwiftData

struct ProduitDetailView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Lieu.ordre) private var lieux: [Lieu]

    let produit: Produit

    @State private var transfertPresente = false
    @State private var ajoutPresente = false
    @State private var suppressionDemandee = false
    @State private var messageErreur: String?

    private var lieuxAvecStock: [(lieu: Lieu, quantite: Int)] {
        lieux.compactMap { lieu in
            let q = produit.stock(dans: lieu)
            return q > 0 ? (lieu, q) : nil
        }
    }

    private var lotsTries: [Lot] {
        produit.lots.sorted {
            ($0.datePeremption ?? .distantFuture, $0.dateAjout) < ($1.datePeremption ?? .distantFuture, $1.dateAjout)
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text(produit.symbole).font(.largeTitle)
                    VStack(alignment: .leading) {
                        Text(produit.nom).font(CachetteTypography.titre)
                        Text("\(produit.stockTotal) unité(s) au total")
                            .font(CachetteTypography.corps)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Par lieu") {
                if lieuxAvecStock.isEmpty {
                    Text("Stock épuisé partout 🍂")
                        .foregroundStyle(.secondary)
                }
                ForEach(lieuxAvecStock, id: \.lieu.id) { entree in
                    HStack {
                        Text("\(entree.lieu.emoji) \(entree.lieu.nom)")
                        Spacer()
                        Text("\(entree.quantite)")
                            .font(CachetteTypography.corps.weight(.semibold))
                        HStack(spacing: 0) {
                            Button {
                                retirer(1, de: entree.lieu)
                            } label: {
                                Image(systemName: "minus").frame(width: 34, height: 30)
                            }
                            Divider().frame(height: 16)
                            Button {
                                ajouter(1, dans: entree.lieu)
                            } label: {
                                Image(systemName: "plus").frame(width: 34, height: 30)
                            }
                        }
                        .buttonStyle(.plain)
                        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 8))
                        .foregroundStyle(CachetteColors.rouxCachette)
                    }
                }
            }

            Section("Lots & péremptions") {
                if lotsTries.isEmpty {
                    Text("Aucun lot en stock").foregroundStyle(.secondary)
                }
                ForEach(lotsTries) { lot in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(lot.quantite) unité(s) — \(lot.lieu?.nom ?? "?")")
                                .font(CachetteTypography.corps)
                            if let numero = lot.numeroLot {
                                Text("Lot \(numero)")
                                    .font(CachetteTypography.legende)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let peremption = lot.datePeremption {
                            Text(peremption, style: .date)
                                .font(CachetteTypography.legende)
                                .foregroundStyle(couleurPeremption(lot))
                        } else {
                            Text("Sans date")
                                .font(CachetteTypography.legende)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Historique") {
                let derniers = produit.mouvements.sorted { $0.date > $1.date }.prefix(10)
                if derniers.isEmpty {
                    Text("Aucun mouvement").foregroundStyle(.secondary)
                }
                ForEach(Array(derniers)) { mouvement in
                    MouvementRow(mouvement: mouvement)
                }
            }

            Section {
                Button(role: .destructive) {
                    suppressionDemandee = true
                } label: {
                    Label("Supprimer ce produit", systemImage: "trash")
                }
            }
        }
        .navigationTitle(produit.nom)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    transfertPresente = true
                } label: {
                    Label("Je pars avec…", systemImage: "figure.walk.departure")
                }
                .disabled(produit.stockTotal == 0)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    ajoutPresente = true
                } label: {
                    Label("J'ai reçu", systemImage: "plus.square.on.square")
                }
            }
        }
        .sheet(isPresented: $transfertPresente) {
            TransfertSheetView(produit: produit)
        }
        .sheet(isPresented: $ajoutPresente) {
            AjoutStockSheetView(produit: produit)
        }
        .confirmationDialog(
            "Supprimer « \(produit.nom) » et tout son stock ?",
            isPresented: $suppressionDemandee,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) { supprimer() }
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

    private func couleurPeremption(_ lot: Lot) -> Color {
        if lot.estPerime { return CachetteColors.terracotta }
        if lot.perimeAvant(jours: 30) { return CachetteColors.ambre }
        return CachetteColors.vertSauge
    }

    private func retirer(_ quantite: Int, de lieu: Lieu) {
        do {
            try StockService(contexte: contexte).retirerStock(produit: produit, lieu: lieu, quantite: quantite)
        } catch {
            messageErreur = error.localizedDescription
        }
    }

    private func ajouter(_ quantite: Int, dans lieu: Lieu) {
        do {
            try StockService(contexte: contexte).ajouterStock(produit: produit, lieu: lieu, quantite: quantite)
        } catch {
            messageErreur = error.localizedDescription
        }
    }

    private func supprimer() {
        do {
            try StockService(contexte: contexte).supprimerProduit(produit)
            dismiss()
        } catch {
            messageErreur = error.localizedDescription
        }
    }
}

struct MouvementRow: View {
    let mouvement: Mouvement

    var body: some View {
        HStack {
            Text(mouvement.delta > 0 ? "↗" : "↘")
                .foregroundStyle(mouvement.delta > 0 ? CachetteColors.vertSauge : CachetteColors.terracotta)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(mouvement.motif.libelle) — \(mouvement.lieuNom)")
                    .font(CachetteTypography.corps)
                Text(mouvement.date, format: .dateTime.day().month().hour().minute())
                    .font(CachetteTypography.legende)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(mouvement.delta > 0 ? "+\(mouvement.delta)" : "\(mouvement.delta)")
                .font(CachetteTypography.corps.weight(.semibold))
                .foregroundStyle(mouvement.delta > 0 ? CachetteColors.vertSauge : CachetteColors.terracotta)
        }
    }
}
