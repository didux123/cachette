import SwiftUI
import SwiftData

/// Création manuelle d'un produit, avec stock initial optionnel.
/// Pré-remplissable par le scan (M3) via `Prefill`.
struct ProduitFormView: View {
    nonisolated struct Prefill {
        var nom = ""
        var type: TypeProduit = .medicament
        var cip13: String?
        var refBDPMCIS: String?
        var conditionnement = 1
        var datePeremption: Date?
        var numeroLot: String?
    }

    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Lieu.ordre) private var lieux: [Lieu]

    var lieuInitial: Lieu?
    var prefill: Prefill?

    @State private var nom = ""
    @State private var type: TypeProduit = .medicament
    @State private var conditionnement = 1
    @State private var seuilActif = false
    @State private var seuil = 5

    @State private var quantiteInitiale = 0
    @State private var lieuStock: Lieu?
    @State private var peremptionActive = false
    @State private var datePeremption = Date.now
    @State private var numeroLot: String?
    @State private var cip13: String?
    @State private var refBDPMCIS: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Produit") {
                    TextField("Nom (ex. Stylo insuline rapide)", text: $nom)
                    Picker("Type", selection: $type) {
                        ForEach(TypeProduit.allCases) { t in
                            Text("\(t.symbole) \(t.libelle)").tag(t)
                        }
                    }
                    Stepper("Unités par boîte : \(conditionnement)", value: $conditionnement, in: 1...500)
                }

                Section("Alerte stock bas") {
                    Toggle("M'alerter quand il en reste peu", isOn: $seuilActif)
                    if seuilActif {
                        Stepper("Seuil : \(seuil) unité(s)", value: $seuil, in: 1...200)
                    }
                }

                Section("Stock de départ (optionnel)") {
                    Stepper("Quantité : \(quantiteInitiale)", value: $quantiteInitiale, in: 0...999)
                    if quantiteInitiale > 0 {
                        Picker("Dans quel lieu ?", selection: $lieuStock) {
                            ForEach(lieux) { lieu in
                                Text("\(lieu.emoji) \(lieu.nom)").tag(Optional(lieu))
                            }
                        }
                        Toggle("Date de péremption", isOn: $peremptionActive)
                        if peremptionActive {
                            DatePicker("Périme le", selection: $datePeremption, displayedComponents: .date)
                        }
                    }
                }
            }
            .navigationTitle("Nouveau produit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { enregistrer() }
                        .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let prefill {
                    nom = prefill.nom
                    type = prefill.type
                    conditionnement = prefill.conditionnement
                    cip13 = prefill.cip13
                    refBDPMCIS = prefill.refBDPMCIS
                    numeroLot = prefill.numeroLot
                    if let peremption = prefill.datePeremption {
                        peremptionActive = true
                        datePeremption = peremption
                        quantiteInitiale = max(quantiteInitiale, 1)
                    }
                }
                if lieuStock == nil {
                    lieuStock = lieuInitial ?? lieux.first
                }
            }
        }
    }

    private func enregistrer() {
        let service = StockService(contexte: contexte)
        do {
            let produit = try service.creerProduit(
                nom: nom.trimmingCharacters(in: .whitespaces),
                type: type,
                cip13: cip13,
                refBDPMCIS: refBDPMCIS,
                conditionnement: conditionnement,
                seuilStockBas: seuilActif ? seuil : nil
            )
            if quantiteInitiale > 0, let lieu = lieuStock {
                try service.ajouterStock(
                    produit: produit,
                    lieu: lieu,
                    quantite: quantiteInitiale,
                    datePeremption: peremptionActive ? datePeremption : nil,
                    numeroLot: numeroLot
                )
            }
            dismiss()
        } catch {
            // Échec d'écriture locale improbable ; on ne ferme pas la feuille.
        }
    }
}
