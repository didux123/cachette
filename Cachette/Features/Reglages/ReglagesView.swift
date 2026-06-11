import SwiftUI

struct ReglagesView: View {
    @AppStorage(ReglagesCles.fenetrePeremptionJours)
    private var fenetrePeremption = ReglagesCles.fenetrePeremptionDefaut
    @AppStorage(ReglagesCles.notificationsActivees)
    private var notificationsActivees = false
    @AppStorage("coffreVerrouActive")
    private var verrouActive = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if notificationsActivees {
                        Label {
                            Text("Notifications activées")
                        } icon: {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(CachetteColors.vertSauge)
                        }
                    } else {
                        Button {
                            Task {
                                notificationsActivees = await CentreNotificationsSysteme()
                                    .demanderAutorisation()
                            }
                        } label: {
                            Label("Activer les notifications", systemImage: "bell.badge")
                        }
                    }
                    Stepper(
                        "Prévenir \(fenetrePeremption) jours avant péremption",
                        value: $fenetrePeremption,
                        in: 7...120,
                        step: 7
                    )
                } header: {
                    Text("Alertes")
                } footer: {
                    Text("Le seuil de stock bas se règle produit par produit, sur sa fiche. Tout est local : aucune donnée ne quitte ton téléphone.")
                }

                Section {
                    Toggle("Verrouiller le coffre (Face ID)", isOn: $verrouActive)
                } header: {
                    Text("Coffre")
                } footer: {
                    Text("Les documents restent chiffrés sur ton téléphone dans tous les cas.")
                }

                Section("À propos") {
                    LabeledContent("Version", value: "0.1.0")
                    Text("Cachette est un outil d'inventaire. Ce n'est pas un dispositif médical et elle ne donne aucun avis médical.")
                        .font(CachetteTypography.legende)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Réglages")
        }
    }
}

#Preview {
    ReglagesView()
}
