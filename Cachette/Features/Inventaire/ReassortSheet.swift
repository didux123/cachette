import SwiftUI
import SwiftData

/// Réassort « j'ai reçu » : on pioche dans la liste des produits suivis —
/// définie à l'onboarding, modifiable dans Réglages — sans rien retaper.
struct ReassortSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Produit.nom) private var produits: [Produit]

    @State private var produitChoisi: Produit?
    @State private var recherche = ""

    private var produitsFiltres: [Produit] {
        guard !recherche.isEmpty else { return produits }
        let terme = recherche.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return produits.filter {
            $0.nom.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(terme)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if produits.isEmpty {
                    MascotteEmptyState(
                        message: "Ta liste de produits suivis est vide.\nAjoute-en depuis le bouton + ou dans Réglages."
                    )
                } else {
                    List(produitsFiltres) { produit in
                        Button {
                            produitChoisi = produit
                        } label: {
                            HStack {
                                Text(produit.type.symbole)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(produit.nom)
                                        .font(CachetteTypography.corps.weight(.medium))
                                    Text("Stock actuel : \(produit.stockTotal)")
                                        .font(CachetteTypography.legende)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(CachetteColors.vertSauge)
                            }
                        }
                        .tint(.primary)
                    }
                    .searchable(text: $recherche, prompt: "Chercher un produit…")
                }
            }
            .navigationTitle("J'ai reçu…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $produitChoisi) { produit in
                AjoutStockSheetView(produit: produit)
            }
        }
    }
}
