import SwiftUI
import SwiftData

/// « Je pars avec N [produit] » : transfert d'un lieu vers un autre (P0-2b).
struct TransfertSheetView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Lieu.ordre) private var lieux: [Lieu]

    let produit: Produit

    @State private var source: Lieu?
    @State private var destination: Lieu?
    @State private var quantite = 1
    @State private var messageErreur: String?

    private var stockSource: Int {
        source.map { produit.stock(dans: $0) } ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Depuis", selection: $source) {
                        ForEach(lieux.filter { produit.stock(dans: $0) > 0 }) { lieu in
                            Text("\(lieu.emoji) \(lieu.nom) — \(produit.stock(dans: lieu))").tag(Optional(lieu))
                        }
                    }
                    Picker("Vers", selection: $destination) {
                        ForEach(lieux.filter { $0.id != source?.id }) { lieu in
                            Text("\(lieu.emoji) \(lieu.nom)").tag(Optional(lieu))
                        }
                    }
                } header: {
                    Text("Trajet")
                } footer: {
                    Text("Les unités qui périment le plus tôt partent en premier, avec leur date de péremption.")
                }

                Section("Quantité") {
                    Stepper("J'emporte \(quantite) unité(s)", value: $quantite, in: 1...max(1, stockSource))
                    if stockSource > 0 {
                        Text("\(stockSource) disponible(s) au départ")
                            .font(CachetteTypography.legende)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Je pars avec…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Transférer") { transferer() }
                        .disabled(source == nil || destination == nil || quantite > stockSource)
                }
            }
            .onAppear { preselectionner() }
            .onChange(of: source) { _, _ in
                quantite = min(quantite, max(1, stockSource))
                if destination?.id == source?.id { destination = nil }
                if destination == nil { preselectionnerDestination() }
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
        .presentationDetents([.medium])
    }

    /// Par défaut : depuis le lieu le mieux fourni, vers « Sur moi » (le cas d'usage type).
    private func preselectionner() {
        if source == nil {
            source = lieux
                .filter { produit.stock(dans: $0) > 0 }
                .max { produit.stock(dans: $0) < produit.stock(dans: $1) }
        }
        preselectionnerDestination()
    }

    private func preselectionnerDestination() {
        if destination == nil {
            destination = lieux.first { $0.estSurMoi && $0.id != source?.id }
                ?? lieux.first { $0.id != source?.id }
        }
    }

    private func transferer() {
        guard let source, let destination else { return }
        do {
            try TransfertService(contexte: contexte)
                .transferer(produit: produit, de: source, vers: destination, quantite: quantite)
            dismiss()
        } catch {
            messageErreur = error.localizedDescription
        }
    }
}

/// Petite feuille « j'ai reçu » : ajout de stock avec lot/péremption optionnels.
struct AjoutStockSheetView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Lieu.ordre) private var lieux: [Lieu]

    let produit: Produit

    @State private var lieu: Lieu?
    @State private var quantite = 1
    @State private var peremptionActive = false
    @State private var datePeremption = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Picker("Dans quel lieu ?", selection: $lieu) {
                    ForEach(lieux) { l in
                        Text("\(l.emoji) \(l.nom)").tag(Optional(l))
                    }
                }
                Stepper("Quantité : \(quantite)", value: $quantite, in: 1...999)
                Toggle("Date de péremption", isOn: $peremptionActive)
                if peremptionActive {
                    DatePicker("Périme le", selection: $datePeremption, displayedComponents: .date)
                }
            }
            .navigationTitle("J'ai reçu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { ajouter() }
                        .disabled(lieu == nil)
                }
            }
            .onAppear {
                if lieu == nil { lieu = lieux.first }
            }
        }
        .presentationDetents([.medium])
    }

    private func ajouter() {
        guard let lieu else { return }
        do {
            try StockService(contexte: contexte).ajouterStock(
                produit: produit,
                lieu: lieu,
                quantite: quantite,
                datePeremption: peremptionActive ? datePeremption : nil
            )
            dismiss()
        } catch {
            // Erreur d'écriture locale improbable.
        }
    }
}
