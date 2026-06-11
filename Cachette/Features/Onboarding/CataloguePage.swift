import SwiftUI
import SwiftData

/// Page d'onboarding : définir d'emblée la liste des produits à suivre.
/// Ensuite, chaque réassort se fait en piochant dans cette liste — plus
/// jamais besoin de tout retaper. Modifiable dans Réglages → Mes produits.
struct CataloguePage: View {
    @Environment(\.modelContext) private var contexte
    @Query(sort: \Produit.nom) private var produits: [Produit]

    let onContinuer: () -> Void

    @State private var nomPersonnalise = ""
    @State private var typePersonnalise: TypeProduit = .medicament

    /// Suggestions pour démarrer vite (diabète et compagnie — tout est modifiable).
    private static let suggestions: [(nom: String, type: TypeProduit)] = [
        ("Stylo insuline rapide", .insuline),
        ("Stylo insuline lente", .insuline),
        ("Cathéters", .catheter),
        ("Capteurs de glycémie", .bandelette),
        ("Bandelettes", .bandelette),
        ("Aiguilles de stylo", .seringue),
        ("Resucrage", .autre),
    ]

    private var suggestionsRestantes: [(nom: String, type: TypeProduit)] {
        Self.suggestions.filter { suggestion in
            !produits.contains { $0.nom.caseInsensitiveCompare(suggestion.nom) == .orderedSame }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                MascotteView(etat: .contente, taille: 90)
                Text("Qu'est-ce que je surveille pour toi ?")
                    .font(CachetteTypography.titre)
                    .foregroundStyle(CachetteColors.brunNoisette)
                Text("Liste une fois ce que tu utilises — ensuite, les réassorts se font en un tap, sans rien retaper.")
                    .font(CachetteTypography.corps)
                    .foregroundStyle(CachetteColors.brunNoisette)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(.top, 32)

            List {
                if !produits.isEmpty {
                    Section("Je suis déjà :") {
                        ForEach(produits) { produit in
                            HStack {
                                Text("\(produit.type.symbole) \(produit.nom)")
                                Spacer()
                                Button {
                                    try? StockService(contexte: contexte).supprimerProduit(produit)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if !suggestionsRestantes.isEmpty {
                    Section("Suggestions — touche pour ajouter") {
                        ForEach(suggestionsRestantes, id: \.nom) { suggestion in
                            Button {
                                ajouter(nom: suggestion.nom, type: suggestion.type)
                            } label: {
                                Label("\(suggestion.type.symbole) \(suggestion.nom)", systemImage: "plus.circle")
                            }
                            .tint(CachetteColors.brunNoisette)
                        }
                    }
                }

                Section("Autre chose ?") {
                    TextField("Nom du produit", text: $nomPersonnalise)
                    Picker("Type", selection: $typePersonnalise) {
                        ForEach(TypeProduit.allCases) { type in
                            Text("\(type.symbole) \(type.libelle)").tag(type)
                        }
                    }
                    Button {
                        ajouter(nom: nomPersonnalise, type: typePersonnalise)
                        nomPersonnalise = ""
                    } label: {
                        Label("Ajouter à ma liste", systemImage: "plus")
                    }
                    .disabled(nomPersonnalise.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)

            Button {
                onContinuer()
            } label: {
                Text(produits.isEmpty ? "Passer cette étape" : "Continuer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(CachetteColors.rouxCachette)
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
        .background(CachetteColors.creme)
    }

    private func ajouter(nom: String, type: TypeProduit) {
        let propre = nom.trimmingCharacters(in: .whitespaces)
        guard !propre.isEmpty else { return }
        try? StockService(contexte: contexte).creerProduit(nom: propre, type: type)
    }
}
