import SwiftUI

struct AppRootView: View {
    var body: some View {
        TabView {
            Tab("Réserves", systemImage: "shippingbox.fill") {
                InventaireView()
            }
            Tab("Scanner", systemImage: "barcode.viewfinder") {
                PlaceholderScreen(titre: "Scanner", message: "Le scan des boîtes arrive bientôt.")
            }
            Tab("Coffre", systemImage: "lock.doc.fill") {
                PlaceholderScreen(titre: "Coffre", message: "Tes ordonnances, toujours sur toi.")
            }
            Tab("Réglages", systemImage: "gearshape.fill") {
                PlaceholderScreen(titre: "Réglages", message: "Seuils, alertes et confidentialité.")
            }
        }
        .tint(CachetteColors.rouxCachette)
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
