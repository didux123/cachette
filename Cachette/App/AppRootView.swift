import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Réserves", systemImage: "shippingbox.fill") {
                InventaireView()
            }
            Tab("Scanner", systemImage: "barcode.viewfinder") {
                ScanView()
            }
            Tab("Coffre", systemImage: "lock.doc.fill") {
                PlaceholderScreen(titre: "Coffre", message: "Tes ordonnances, toujours sur toi.")
            }
            Tab("Réglages", systemImage: "gearshape.fill") {
                ReglagesView()
            }
        }
        .tint(CachetteColors.rouxCachette)
        .onReceive(NotificationCenter.default.publisher(for: .cachetteStockMute)) { _ in
            Task { await Alertes.reconcilier(contexte: contexte) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await Alertes.reconcilier(contexte: contexte) }
            }
        }
    }
}

private struct PlaceholderScreen: View {
    let titre: String
    let message: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("🐿️")
                    .font(.system(size: 56))
                Text(message)
                    .font(CachetteTypography.corps)
                    .foregroundStyle(CachetteColors.brunNoisette)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CachetteColors.creme)
            .navigationTitle(titre)
        }
    }
}

#Preview {
    AppRootView()
}
