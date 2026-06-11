import SwiftUI
import SwiftData

/// Page d'onboarding : définir d'emblée la liste des produits à suivre.
/// Deux chemins : choisir sa (ses) condition(s) chronique(s) → suggestions
/// à cocher, ou tout écrire à la main (emoji au choix + nom).
/// Modifiable ensuite dans Réglages → Mes produits suivis.
struct CataloguePage: View {
    @Environment(\.modelContext) private var contexte
    @Query(sort: \Produit.nom) private var produits: [Produit]

    let onContinuer: () -> Void

    @State private var conditionsChoisies: Set<String> = []
    @State private var nomPersonnalise = ""
    @State private var emojiPersonnalise = "💊"

    private var suggestionsVisibles: [SuggestionProduit] {
        ConditionChronique.toutes
            .filter { conditionsChoisies.contains($0.id) }
            .flatMap(\.suggestions)
            .filter { suggestion in
                !produits.contains { $0.nom.caseInsensitiveCompare(suggestion.nom) == .orderedSame }
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                MascotteView(etat: .contente, taille: 80)
                Text("Qu'est-ce que je surveille pour toi ?")
                    .font(CachetteTypography.titre)
                    .foregroundStyle(CachetteColors.brunNoisette)
                Text("Liste une fois ce que tu utilises — les réassorts se feront ensuite en un tap.")
                    .font(CachetteTypography.corps)
                    .foregroundStyle(CachetteColors.brunNoisette)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(.top, 24)

            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ConditionChronique.toutes) { condition in
                                let active = conditionsChoisies.contains(condition.id)
                                Button {
                                    if active {
                                        conditionsChoisies.remove(condition.id)
                                    } else {
                                        conditionsChoisies.insert(condition.id)
                                    }
                                } label: {
                                    Text("\(condition.emoji) \(condition.nom)")
                                        .font(CachetteTypography.legende.weight(active ? .semibold : .regular))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            active ? CachetteColors.rouxCachette.opacity(0.18) : Color(.secondarySystemBackground),
                                            in: .capsule
                                        )
                                        .overlay {
                                            if active {
                                                Capsule().strokeBorder(CachetteColors.rouxCachette, lineWidth: 1.5)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                } header: {
                    Text("Ma situation (optionnel)")
                } footer: {
                    conditionsChoisies.isEmpty
                        ? Text("Touche une situation pour voir des suggestions, ou construis ta liste à la main juste en dessous.")
                        : nil
                }

                if !suggestionsVisibles.isEmpty {
                    Section("Suggestions — touche pour ajouter") {
                        ForEach(suggestionsVisibles) { suggestion in
                            Button {
                                ajouter(nom: suggestion.nom, emoji: suggestion.emoji, type: suggestion.type)
                            } label: {
                                Label("\(suggestion.emoji) \(suggestion.nom)", systemImage: "plus.circle")
                            }
                            .tint(CachetteColors.brunNoisette)
                        }
                    }
                }

                Section("À la main : ton emoji + un nom") {
                    EmojiPickerRow(emoji: $emojiPersonnalise)
                    HStack {
                        Text(emojiPersonnalise)
                        TextField("Nom du produit", text: $nomPersonnalise)
                        Button {
                            ajouter(nom: nomPersonnalise, emoji: emojiPersonnalise, type: .autre)
                            nomPersonnalise = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(CachetteColors.vertSauge)
                        }
                        .disabled(nomPersonnalise.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if !produits.isEmpty {
                    Section("Ma liste") {
                        ForEach(produits) { produit in
                            HStack {
                                Text("\(produit.symbole) \(produit.nom)")
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
            }
            .scrollContentBackground(.hidden)

            Button {
                onContinuer()
            } label: {
                Text(produits.isEmpty ? "Passer cette étape" : "Continuer avec \(produits.count) produit\(produits.count > 1 ? "s" : "")")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(CachetteColors.rouxCachette)
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
        .background(CachetteColors.creme)
    }

    private func ajouter(nom: String, emoji: String, type: TypeProduit) {
        let propre = nom.trimmingCharacters(in: .whitespaces)
        guard !propre.isEmpty else { return }
        try? StockService(contexte: contexte).creerProduit(nom: propre, type: type, emoji: emoji)
    }
}
