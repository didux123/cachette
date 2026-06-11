import SwiftUI
import SwiftData

/// Journal global des mouvements, tous produits confondus.
struct HistoriqueView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Mouvement.date, order: .reverse) private var mouvements: [Mouvement]

    var body: some View {
        NavigationStack {
            Group {
                if mouvements.isEmpty {
                    VStack(spacing: 12) {
                        Text("🐿️").font(.system(size: 56))
                        Text("Aucun mouvement pour l'instant.\nChaque ajout, usage ou transfert apparaîtra ici.")
                            .font(CachetteTypography.corps)
                            .foregroundStyle(CachetteColors.brunNoisette)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(mouvements) { mouvement in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(mouvement.produitNom)
                                        .font(CachetteTypography.corps.weight(.medium))
                                    Spacer()
                                    Text(mouvement.delta > 0 ? "+\(mouvement.delta)" : "\(mouvement.delta)")
                                        .font(CachetteTypography.corps.weight(.semibold))
                                        .foregroundStyle(mouvement.delta > 0 ? CachetteColors.vertSauge : CachetteColors.terracotta)
                                }
                                Text("\(mouvement.motif.libelle) — \(mouvement.lieuNom)")
                                    .font(CachetteTypography.legende)
                                    .foregroundStyle(.secondary)
                                Text(mouvement.date, format: .dateTime.day().month().year().hour().minute())
                                    .font(CachetteTypography.legende)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .fondCachette(mascotte: .vigilante, alignement: .bottomLeading)
            .navigationTitle("Historique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
