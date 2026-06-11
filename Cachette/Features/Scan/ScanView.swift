import SwiftUI
import SwiftData

/// Résultat d'un scan prêt à être confirmé par l'utilisateur.
struct ResultatScan: Identifiable {
    let id = UUID()
    let payload: GS1Payload
    let presentation: BDPMPresentation?
}

/// Onglet « Scanner » : caméra live sur iPhone, saisie manuelle en repli
/// (simulateur, caméra refusée, code illisible).
struct ScanView: View {
    @Environment(\.modelContext) private var contexte

    @State private var resultat: ResultatScan?
    @State private var codeManuel = ""
    @State private var scanConfirme = false

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerView.estSupporte {
                    scannerLive
                } else {
                    saisieManuelle
                }
            }
            .navigationTitle("Scanner une boîte")
            .sheet(item: $resultat) { resultat in
                ScanResultSheet(resultat: resultat)
            }
        }
    }

    private var scannerLive: some View {
        ZStack(alignment: .bottom) {
            DataScannerView(
                onScan: { traiter($0) },
                enPause: resultat != nil
            )
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 6) {
                Text("Vise le petit carré (Datamatrix) de la boîte")
                    .font(CachetteTypography.corps)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: .capsule)
            }
            .padding(.bottom, 24)
        }
    }

    private var saisieManuelle: some View {
        Form {
            Section {
                Text("📷 La caméra n'est pas disponible ici. Saisis le code CIP13 (13 chiffres sous le code-barres) :")
                    .font(CachetteTypography.corps)
                TextField("3400935955838", text: $codeManuel)
                    .keyboardType(.numberPad)
                    .font(.system(.body, design: .monospaced))
                Button("Rechercher") {
                    traiter(codeManuel)
                }
                .disabled(codeManuel.trimmingCharacters(in: .whitespaces).count < 13)
            } footer: {
                Text("Astuce : tu peux aussi coller un payload Datamatrix complet (01…17…10…).")
            }
        }
    }

    private func traiter(_ brut: String) {
        let nettoye = brut.trimmingCharacters(in: .whitespacesAndNewlines)

        var payload: GS1Payload
        if nettoye.count == 13, nettoye.allSatisfy(\.isNumber) {
            // EAN-13 simple : le code EST le CIP13.
            payload = GS1Payload(gtin14: "0" + nettoye)
        } else if let parse = GS1Parser.parse(nettoye) {
            payload = parse
        } else {
            return
        }

        let presentation = payload.cip13.flatMap { cip in
            try? BDPMDatabase().presentation(cip13: cip)
        }
        resultat = ResultatScan(payload: payload, presentation: presentation)
    }
}
