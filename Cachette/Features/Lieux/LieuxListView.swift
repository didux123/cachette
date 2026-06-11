import SwiftUI
import SwiftData

struct LieuxListView: View {
    @Environment(\.modelContext) private var contexte
    @Query(sort: \Lieu.ordre) private var lieux: [Lieu]

    @State private var lieuEnEdition: Lieu?
    @State private var creationPresentee = false
    @State private var messageErreur: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(lieux) { lieu in
                    LieuRow(lieu: lieu)
                        .contentShape(Rectangle())
                        .onTapGesture { lieuEnEdition = lieu }
                        .swipeActions(edge: .trailing) {
                            if !lieu.estSurMoi {
                                Button(role: .destructive) {
                                    supprimer(lieu)
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            .fondCachette(mascotte: .sereine)
            .navigationTitle("Mes lieux")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        creationPresentee = true
                    } label: {
                        Label("Ajouter un lieu", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $creationPresentee) {
                LieuFormView(lieu: nil)
            }
            .sheet(item: $lieuEnEdition) { lieu in
                LieuFormView(lieu: lieu)
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
    }

    private func supprimer(_ lieu: Lieu) {
        do {
            try StockService(contexte: contexte).supprimerLieu(lieu)
        } catch {
            messageErreur = error.localizedDescription
        }
    }
}

private struct LieuRow: View {
    let lieu: Lieu

    var body: some View {
        HStack(spacing: 12) {
            Text(lieu.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color(hexString: lieu.couleurHex).opacity(0.18), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(lieu.nom)
                    .font(CachetteTypography.corps.weight(.medium))
                Text(lieu.estSurMoi ? "Voyage toujours avec toi" : lieu.type.libelle)
                    .font(CachetteTypography.legende)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if lieu.estSurMoi {
                Image(systemName: "figure.walk")
                    .foregroundStyle(CachetteColors.rouxCachette)
            }
        }
    }
}

#Preview {
    LieuxListView()
        .modelContainer(ModelContainerFactory.inMemory())
}
