import SwiftUI
import SwiftData

/// Assistant « Je pars » (P1-3) : destination + durée → estimation des
/// besoins → checklist de transfert pré-remplie vers « Sur moi ».
struct JeParsView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Lieu.ordre) private var lieux: [Lieu]
    @Query(sort: \Produit.nom) private var produits: [Produit]

    @State private var destination: Lieu?
    @State private var dureeJours = 7
    @State private var quantites: [UUID: Int] = [:]
    @State private var transfertEffectue = false
    @State private var messageErreur: String?

    private var surMoi: Lieu? {
        lieux.first { $0.estSurMoi }
    }

    /// Lieu source : le mieux fourni hors destination et hors « Sur moi ».
    private func source(pour produit: Produit) -> Lieu? {
        lieux
            .filter { !$0.estSurMoi && $0.id != destination?.id && produit.stock(dans: $0) > 0 }
            .max { produit.stock(dans: $0) < produit.stock(dans: $1) }
    }

    private var estimations: [EstimationProduit] {
        guard let destination else { return [] }
        let entrees = produits.map { produit in
            (
                produit: ProduitSnapshot(
                    id: produit.id,
                    nom: produit.nom,
                    conditionnement: produit.conditionnement,
                    stockDestination: produit.stock(dans: destination)
                ),
                mouvementsUsage: produit.mouvements
                    .filter { $0.motif == .usage }
                    .map { (delta: $0.delta, date: $0.date) }
            )
        }
        return TripEstimator.estimer(produits: entrees, dureeJours: dureeJours)
    }

    var body: some View {
        NavigationStack {
            Group {
                if transfertEffectue {
                    confirmation
                } else {
                    formulaire
                }
            }
            .fondCachette(mascotte: .enVoyage)
            .navigationTitle("Je pars…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(transfertEffectue ? "Fermer" : "Annuler") { dismiss() }
                }
            }
        }
    }

    // MARK: - Formulaire

    private var formulaire: some View {
        Form {
            Section("Mon séjour") {
                Picker("Destination", selection: $destination) {
                    Text("Choisir…").tag(Optional<Lieu>.none)
                    ForEach(lieux.filter { !$0.estSurMoi }) { lieu in
                        Text("\(lieu.emoji) \(lieu.nom)").tag(Optional(lieu))
                    }
                }
                Stepper("Durée : \(dureeJours) jour\(dureeJours > 1 ? "s" : "")", value: $dureeJours, in: 1...90)
            }

            if destination != nil {
                Section {
                    ForEach(estimations) { estimation in
                        ligneEstimation(estimation)
                    }
                } header: {
                    Text("À emporter (estimation sur ta consommation réelle)")
                } footer: {
                    Text("L'estimation se base sur tes usages des \(TripEstimator.fenetreJours) derniers jours, avec une marge de sécurité de 20 %. Les produits transférés vont dans « Sur moi ».")
                }

                Section {
                    Button {
                        preparerLePochon()
                    } label: {
                        Label("Préparer mon pochon", systemImage: "figure.walk.departure")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(quantitesAPreparer.isEmpty)
                }
            }
        }
        .onChange(of: destination) { _, _ in preRemplir() }
        .onChange(of: dureeJours) { _, _ in preRemplir() }
        .alert("Oups", isPresented: .init(
            get: { messageErreur != nil },
            set: { if !$0 { messageErreur = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(messageErreur ?? "")
        }
    }

    @ViewBuilder
    private func ligneEstimation(_ estimation: EstimationProduit) -> some View {
        let quantite = quantites[estimation.id] ?? 0
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(estimation.nomProduit)
                    .font(CachetteTypography.corps.weight(.medium))
                Spacer()
                if let besoin = estimation.besoin {
                    Text("besoin ~\(besoin) · sur place \(estimation.stockDestination)")
                        .font(CachetteTypography.legende)
                        .foregroundStyle(.secondary)
                } else {
                    Text("pas assez d'historique")
                        .font(CachetteTypography.legende)
                        .foregroundStyle(.secondary)
                }
            }
            Stepper(
                quantite > 0 ? "J'emporte \(quantite)" : "Je n'emporte rien",
                value: .init(
                    get: { quantites[estimation.id] ?? 0 },
                    set: { quantites[estimation.id] = $0 }
                ),
                in: 0...999
            )
            .font(CachetteTypography.corps)
        }
        .padding(.vertical, 2)
    }

    private var quantitesAPreparer: [(produit: Produit, quantite: Int)] {
        produits.compactMap { produit in
            guard let quantite = quantites[produit.id], quantite > 0 else { return nil }
            return (produit, quantite)
        }
    }

    private func preRemplir() {
        quantites = Dictionary(
            uniqueKeysWithValues: estimations.map { ($0.id, $0.aEmporter ?? 0) }
        )
    }

    private func preparerLePochon() {
        guard let surMoi else { return }
        let transfert = TransfertService(contexte: contexte)
        do {
            for (produit, quantite) in quantitesAPreparer {
                guard let source = source(pour: produit) else { continue }
                let disponible = produit.stock(dans: source)
                guard disponible > 0 else { continue }
                try transfert.transferer(
                    produit: produit,
                    de: source,
                    vers: surMoi,
                    quantite: min(quantite, disponible)
                )
            }
            transfertEffectue = true
        } catch {
            messageErreur = error.localizedDescription
        }
    }

    // MARK: - Confirmation

    private var confirmation: some View {
        VStack(spacing: 16) {
            Spacer()
            MascotteView(etat: .enVoyage, taille: 150)
            Text("Pochon prêt !")
                .font(CachetteTypography.titre)
                .foregroundStyle(CachetteColors.brunNoisette)
            Text("Tout est dans « Sur moi ». Bon séjour — à l'arrivée, tu pourras déposer ce que tu ranges sur place.")
                .font(CachetteTypography.corps)
                .foregroundStyle(CachetteColors.brunNoisette)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}
