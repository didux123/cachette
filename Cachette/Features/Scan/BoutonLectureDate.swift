import SwiftUI

/// Bouton réutilisable « lire la date sur la boîte » → DateOCRSheet.
struct BoutonLectureDate: View {
    let onDateValidee: (Date) -> Void
    @State private var ocrPresente = false

    var body: some View {
        Button {
            ocrPresente = true
        } label: {
            Label("Lire la date sur la boîte", systemImage: "text.viewfinder")
        }
        .sheet(isPresented: $ocrPresente) {
            DateOCRSheet(onDateValidee: onDateValidee)
        }
    }
}
