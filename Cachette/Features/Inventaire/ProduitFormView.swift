import SwiftUI
import SwiftData

/// Création d'un produit à suivre : juste le produit (nom, type, alerte).
/// Le stock se range ensuite via « J'ai reçu » — proposé automatiquement
/// après la création.
struct ProduitFormView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var dismiss

    /// Appelé après création, pour proposer directement le rangement du stock.
    var onCree: ((Produit) -> Void)?

    @State private var nom = ""
    @State private var type: TypeProduit = .medicament
    @State private var conditionnement = 1
    @State private var seuilActif = false
    @State private var seuil = 5

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom (ex. Stylo insuline rapide)", text: $nom)
                    Picker("Type", selection: $type) {
                        ForEach(TypeProduit.allCases) { t in
                            Text("\(t.symbole) \(t.libelle)").tag(t)
                        }
                    }
                    Stepper("Unités par boîte : \(conditionnement)", value: $conditionnement, in: 1...500)
                } header: {
                    Text("Produit")
                } footer: {
                    Text("Juste après, je te proposerai de ranger ce que tu en as déjà.")
                }

                Section("Alerte stock bas") {
                    Toggle("M'alerter quand il en reste peu", isOn: $seuilActif)
                    if seuilActif {
                        Stepper("Seuil : \(seuil) unité(s)", value: $seuil, in: 1...200)
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
        }
    }

    private func enregistrer() {
        do {
            let produit = try StockService(contexte: contexte).creerProduit(
                nom: nom.trimmingCharacters(in: .whitespaces),
                type: type,
                conditionnement: conditionnement,
                seuilStockBas: seuilActif ? seuil : nil
            )
            dismiss()
            onCree?(produit)
        } catch {
            // Échec d'écriture locale improbable ; on ne ferme pas la feuille.
        }
    }
}
