import SwiftUI
import SwiftData

/// Réglages → la liste des produits suivis (le « catalogue » défini à
/// l'onboarding) : ajout, modification du seuil d'alerte, suppression.
struct ProduitsSuivisView: View {
    @Environment(\.modelContext) private var contexte
    @Query(sort: \Produit.nom) private var produits: [Produit]

    @State private var creationPresentee = false

    var body: some View {
        Group {
            if produits.isEmpty {
                MascotteEmptyState(
                    message: "Aucun produit suivi pour l'instant.\nAjoute ce que tu utilises au quotidien.",
                    boutonTitre: "Ajouter un produit"
                ) {
                    creationPresentee = true
                }
            } else {
                List {
                    Section {
                        ForEach(produits) { produit in
                            NavigationLink {
                                ProduitDetailView(produit: produit)
                            } label: {
                                HStack {
                                    Text(produit.symbole)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(produit.nom)
                                            .font(CachetteTypography.corps.weight(.medium))
                                        Text(sousTitre(produit))
                                            .font(CachetteTypography.legende)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    try? StockService(contexte: contexte).supprimerProduit(produit)
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    } footer: {
                        Text("Supprimer un produit efface aussi son stock ; son historique reste consultable.")
                    }
                }
            }
        }
        .navigationTitle("Mes produits suivis")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creationPresentee = true
                } label: {
                    Label("Ajouter", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $creationPresentee) {
            ProduitFormView()
        }
    }

    private func sousTitre(_ produit: Produit) -> String {
        var morceaux = ["\(produit.stockTotal) en stock"]
        if let seuil = produit.seuilStockBas {
            morceaux.append("alerte sous \(seuil)")
        }
        return morceaux.joined(separator: " · ")
    }
}
