import SwiftUI
import SwiftData

/// Confirmation d'ajout après scan : produit reconnu (BDPM) ou création
/// manuelle pré-remplie avec le code lu. Ajout en 1 tap (critère P0-4).
struct ScanResultSheet: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Lieu.ordre) private var lieux: [Lieu]
    @Query private var produits: [Produit]

    let resultat: ResultatScan

    @State private var nom = ""
    @State private var type: TypeProduit = .medicament
    @State private var quantite = 1
    @State private var lieu: Lieu?
    @State private var peremptionActive = false
    @State private var datePeremption = Date.now

    /// Produit déjà connu (même CIP13) → on ajoute du stock au lieu de créer.
    private var produitExistant: Produit? {
        guard let cip = resultat.payload.cip13 else { return nil }
        return produits.first { $0.cip13 == cip }
    }

    private var estReconnu: Bool {
        resultat.presentation != nil || produitExistant != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let existant = produitExistant {
                        Label {
                            VStack(alignment: .leading) {
                                Text(existant.nom).font(CachetteTypography.corps.weight(.semibold))
                                Text("Déjà dans ta réserve — stock actuel : \(existant.stockTotal)")
                                    .font(CachetteTypography.legende)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Text("🎉")
                        }
                    } else if let presentation = resultat.presentation {
                        Label {
                            VStack(alignment: .leading) {
                                Text(presentation.denomination)
                                    .font(CachetteTypography.corps.weight(.semibold))
                                if let libelle = presentation.libellePresentation {
                                    Text(libelle)
                                        .font(CachetteTypography.legende)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Text("✅")
                        }
                    } else {
                        Label {
                            Text("Code non reconnu — complète le nom :")
                        } icon: {
                            Text("🤔")
                        }
                        TextField("Nom du produit", text: $nom)
                        Picker("Type", selection: $type) {
                            ForEach(TypeProduit.allCases) { t in
                                Text("\(t.symbole) \(t.libelle)").tag(t)
                            }
                        }
                    }
                    if let cip = resultat.payload.cip13 {
                        LabeledContent("CIP13") {
                            Text(cip).font(.system(.footnote, design: .monospaced))
                        }
                    }
                    if let lot = resultat.payload.numeroLot {
                        LabeledContent("Lot", value: lot)
                    }
                } header: {
                    Text("Produit")
                }

                Section("Ajout") {
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
            }
            .navigationTitle(estReconnu ? "Boîte reconnue" : "Nouvelle boîte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { ajouter() }
                        .disabled(lieu == nil || (!estReconnu && nom.trimmingCharacters(in: .whitespaces).isEmpty))
                }
            }
            .onAppear { preremplir() }
        }
    }

    private func preremplir() {
        if lieu == nil { lieu = lieux.first }
        if let presentation = resultat.presentation {
            nom = presentation.denomination
            quantite = presentation.unitesParBoite ?? 1
        }
        if let peremption = resultat.payload.datePeremption {
            peremptionActive = true
            datePeremption = peremption
        }
    }

    private func ajouter() {
        guard let lieu else { return }
        let service = StockService(contexte: contexte)
        do {
            let produit: Produit
            if let existant = produitExistant {
                produit = existant
            } else {
                produit = try service.creerProduit(
                    nom: nom.trimmingCharacters(in: .whitespaces),
                    type: resultat.presentation != nil ? .medicament : type,
                    cip13: resultat.payload.cip13,
                    refBDPMCIS: resultat.presentation?.cis,
                    conditionnement: resultat.presentation?.unitesParBoite ?? 1
                )
            }
            try service.ajouterStock(
                produit: produit,
                lieu: lieu,
                quantite: quantite,
                datePeremption: peremptionActive ? datePeremption : nil,
                numeroLot: resultat.payload.numeroLot
            )
            dismiss()
        } catch {
            // Erreur d'écriture locale improbable ; la feuille reste ouverte.
        }
    }
}
