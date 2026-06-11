import SwiftUI

/// Premier lancement : bienvenue portée par la mascotte, disclaimer légal
/// (garde-fou §10 — obligatoire), opt-in notifications.
struct OnboardingView: View {
    @AppStorage("onboardingTermine") private var onboardingTermine = false
    @AppStorage(ReglagesCles.notificationsActivees) private var notificationsActivees = false

    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            bienvenue.tag(0)
            disclaimer.tag(1)
            notifications.tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(CachetteColors.creme)
    }

    // MARK: - Pages

    private var bienvenue: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("mascotte-hero")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
            Text("Salut, moi c'est Cachette !")
                .font(CachetteTypography.grandTitre)
                .foregroundStyle(CachetteColors.brunNoisette)
            Text("Je veille sur tes réserves de traitement et de matériel, réparties partout où tu vis — et je te préviens avant que ça manque ou que ça périme.")
                .font(CachetteTypography.corps)
                .foregroundStyle(CachetteColors.brunNoisette)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                withAnimation { page = 1 }
            } label: {
                Text("Continuer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(CachetteColors.rouxCachette)
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }

    private var disclaimer: some View {
        VStack(spacing: 20) {
            Spacer()
            MascotteView(etat: .vigilante, taille: 120)
            Text("Une chose importante")
                .font(CachetteTypography.titre)
                .foregroundStyle(CachetteColors.brunNoisette)
            VStack(alignment: .leading, spacing: 12) {
                Label("Cachette est un outil d'inventaire : elle compte, range et te prévient.", systemImage: "checkmark.circle.fill")
                Label("Ce n'est pas un dispositif médical : aucune dose, aucun conseil de traitement, aucun rappel de prise.", systemImage: "xmark.circle")
                Label("Pour toute question sur ton traitement, c'est ton équipe médicale qui sait.", systemImage: "stethoscope")
            }
            .font(CachetteTypography.corps)
            .foregroundStyle(CachetteColors.brunNoisette)
            .padding(.horizontal, 32)
            Spacer()
            Button {
                withAnimation { page = 2 }
            } label: {
                Text("J'ai compris")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(CachetteColors.rouxCachette)
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }

    private var notifications: some View {
        VStack(spacing: 20) {
            Spacer()
            MascotteView(etat: .contente, taille: 120)
            Text("Je te préviens au bon moment ?")
                .font(CachetteTypography.titre)
                .foregroundStyle(CachetteColors.brunNoisette)
            Text("Stock qui baisse, péremption qui approche : une petite notification douce, jamais d'alarme stressante. Tout reste sur ton téléphone — aucun compte, aucun serveur.")
                .font(CachetteTypography.corps)
                .foregroundStyle(CachetteColors.brunNoisette)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 10) {
                Button {
                    Task {
                        notificationsActivees = await CentreNotificationsSysteme().demanderAutorisation()
                        onboardingTermine = true
                    }
                } label: {
                    Text("Activer les notifications")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(CachetteColors.rouxCachette)

                Button("Plus tard") {
                    onboardingTermine = true
                }
                .font(CachetteTypography.corps)
                .tint(CachetteColors.brunNoisette)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    OnboardingView()
}
