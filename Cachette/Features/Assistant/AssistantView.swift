import SwiftUI
import SwiftData

/// Assistant local : gère le stock à la voix ou au clavier, en français.
/// « Je prends 3 cathéters de chez moi pour aller chez mes parents » →
/// proposition d'action → confirmation explicite → exécution via les services.
/// 100 % local : reconnaissance vocale Apple + interpréteur embarqué.
struct AssistantView: View {
    @Environment(\.modelContext) private var contexte
    @Query(sort: \Produit.nom) private var produits: [Produit]
    @Query(sort: \Lieu.ordre) private var lieux: [Lieu]

    @State private var messages: [MessageChat] = []
    @State private var saisie = ""
    @State private var dictee = Dictee()
    @FocusState private var champFocalise: Bool

    struct MessageChat: Identifiable {
        enum Role { case utilisateur, assistant }
        let id = UUID()
        let role: Role
        let texte: String
        /// Actions en attente de confirmation, portées par ce message
        /// (une phrase peut en contenir plusieurs).
        var actions: [IntentionAssistant]?
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                conversation
                barreSaisie
            }
            .fondCachette()
            .navigationTitle("Cachette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // La mascotte en personne dans la barre de titre.
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 7) {
                        Image("mascotte-sereine")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 30)
                        Text("Cachette")
                            .font(CachetteTypography.titre)
                            .foregroundStyle(CachetteColors.brunNoisette)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Cachette, ton assistante")
                }
            }
            .onChange(of: dictee.transcription) { _, nouveau in
                if !nouveau.isEmpty { saisie = nouveau }
            }
            .onChange(of: dictee.enEcoute) { ancien, nouveau in
                // Fin de dictée : on envoie ce qui a été compris.
                if ancien, !nouveau, !saisie.trimmingCharacters(in: .whitespaces).isEmpty {
                    envoyer()
                }
            }
        }
    }

    // MARK: - Conversation

    private var conversation: some View {
        ScrollViewReader { defileur in
            ScrollView {
                VStack(spacing: 10) {
                    if messages.isEmpty {
                        accueil
                    }
                    ForEach(messages) { message in
                        bulle(message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                if let dernier = messages.last?.id {
                    withAnimation { defileur.scrollTo(dernier, anchor: .bottom) }
                }
            }
        }
    }

    private var accueil: some View {
        VStack(spacing: 14) {
            MascotteView(etat: .contente, taille: 110)
            Text("Dis-moi ce qui bouge, je m'occupe des comptes !")
                .font(CachetteTypography.titre)
                .foregroundStyle(CachetteColors.brunNoisette)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 8) {
                exemple("« Je prends 3 cathéters de chez moi pour aller chez mes parents »")
                exemple("« J'ai utilisé 2 bandelettes »")
                exemple("« J'ai reçu 5 capteurs chez moi »")
                exemple("« Combien il me reste de stylos ? »")
            }
            .padding(14)
            .background(Color(.secondarySystemBackground).opacity(0.7), in: .rect(cornerRadius: 14))
        }
        .padding(.top, 24)
    }

    private func exemple(_ texte: String) -> some View {
        Button {
            saisie = texte
                .replacingOccurrences(of: "« ", with: "")
                .replacingOccurrences(of: " »", with: "")
            envoyer()
        } label: {
            Text(texte)
                .font(CachetteTypography.legende)
                .foregroundStyle(CachetteColors.brunNoisette)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private func bulle(_ message: MessageChat) -> some View {
        HStack {
            if message.role == .utilisateur { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 10) {
                Text(message.texte)
                    .font(CachetteTypography.corps)
                if let actions = message.actions {
                    HStack {
                        Button(actions.count > 1 ? "Tout confirmer" : "Confirmer") {
                            confirmer(actions, messageID: message.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CachetteColors.vertSauge)
                        Button("Annuler") {
                            annuler(messageID: message.id)
                        }
                        .buttonStyle(.bordered)
                        .tint(CachetteColors.brunNoisette)
                    }
                }
            }
            .padding(12)
            .background(
                message.role == .utilisateur
                    ? CachetteColors.rouxCachette.opacity(0.16)
                    : Color(.secondarySystemBackground),
                in: .rect(cornerRadius: 16)
            )
            .foregroundStyle(CachetteColors.brunNoisette)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    // MARK: - Saisie

    private var barreSaisie: some View {
        VStack(spacing: 6) {
            if let erreur = dictee.messageErreur {
                Label(erreur, systemImage: "exclamationmark.bubble")
                    .font(CachetteTypography.legende)
                    .foregroundStyle(CachetteColors.terracotta)
                    .padding(.horizontal, 16)
                    .transition(.opacity)
            }

            HStack(spacing: 10) {
                // Champ en capsule, fond clair, liseré discret.
                HStack(spacing: 8) {
                    TextField(
                        dictee.enEcoute ? "Je t'écoute… 🎙️" : "Écris ou dicte ta phrase…",
                        text: $saisie,
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .font(CachetteTypography.corps)
                    .focused($champFocalise)
                    .onSubmit { envoyer() }

                    if !saisie.isEmpty {
                        Button {
                            saisie = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .accessibilityLabel("Effacer")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(
                            dictee.enEcoute
                                ? CachetteColors.terracotta.opacity(0.6)
                                : CachetteColors.brunNoisette.opacity(0.15),
                            lineWidth: dictee.enEcoute ? 1.6 : 1
                        )
                }

                // Micro : rond plein, terracotta quand il écoute.
                Button {
                    dictee.basculer()
                } label: {
                    Image(systemName: dictee.enEcoute ? "stop.fill" : "mic.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            dictee.enEcoute ? CachetteColors.terracotta : CachetteColors.rouxCachette,
                            in: .circle
                        )
                        .symbolEffect(.pulse, isActive: dictee.enEcoute)
                }
                .accessibilityLabel(dictee.enEcoute ? "Arrêter la dictée" : "Dicter")

                // Envoi : n'apparaît que quand il y a quelque chose à envoyer.
                if !saisie.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        envoyer()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(CachetteColors.vertSauge, in: .circle)
                    }
                    .accessibilityLabel("Envoyer")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .animation(.spring(duration: 0.25), value: saisie.isEmpty)
        .animation(.spring(duration: 0.25), value: dictee.enEcoute)
        .background(.bar)
    }

    // MARK: - Logique

    private func envoyer() {
        let phrase = saisie.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }
        saisie = ""
        champFocalise = false // range le clavier : la réponse reste visible
        messages.append(MessageChat(role: .utilisateur, texte: phrase))

        let intentions = CommandeInterpreteur.interpreter(
            phrase,
            produits: produits.map { ProduitRef(id: $0.id, nom: $0.nom) },
            lieux: lieux.map { LieuRef(id: $0.id, nom: $0.nom, estSurMoi: $0.estSurMoi) }
        )

        // Les questions de stock et les incompréhensions se répondent direct ;
        // les actions s'accumulent dans UNE proposition à confirmer.
        var actionsAConfirmer: [IntentionAssistant] = []
        for intention in intentions {
            switch intention {
            case .stock(let produitID):
                messages.append(MessageChat(role: .assistant, texte: reponseStock(produitID)))
            case .incomprise(let raison):
                messages.append(MessageChat(role: .assistant, texte: "🤔 \(raison)"))
            default:
                actionsAConfirmer.append(intention)
            }
        }

        if !actionsAConfirmer.isEmpty {
            let lignes = actionsAConfirmer.map(resume).joined(separator: "\n")
            let question = actionsAConfirmer.count > 1
                ? "\(lignes)\n\nJe fais ces \(actionsAConfirmer.count) mouvements ?"
                : "\(lignes)\n\nJe confirme ?"
            messages.append(MessageChat(role: .assistant, texte: question, actions: actionsAConfirmer))
        }
    }

    private func resume(_ intention: IntentionAssistant) -> String {
        switch intention {
        case .transfert(let produitID, let sourceID, let destinationID, let quantite):
            "🚚 \(quantite) × \(nomProduit(produitID)) : \(nomLieu(sourceID)) → \(nomLieu(destinationID))"
        case .usage(let produitID, let lieuID, let quantite):
            "✏️ \(quantite) × \(nomProduit(produitID)) utilisé(s)\(lieuID.map { " — \(nomLieu($0))" } ?? "")"
        case .reception(let produitID, let lieuID, let quantite):
            "📦 +\(quantite) × \(nomProduit(produitID))\(lieuID.map { " — \(nomLieu($0))" } ?? "")"
        default:
            ""
        }
    }

    private func confirmer(_ intentions: [IntentionAssistant], messageID: UUID) {
        retirerAction(messageID: messageID)
        var bilans: [String] = []

        for intention in intentions {
            do {
                if let bilan = try executer(intention) {
                    bilans.append("✅ \(bilan)")
                }
            } catch {
                bilans.append("❌ \(resume(intention)) — \(error.localizedDescription)")
            }
        }
        messages.append(MessageChat(role: .assistant, texte: bilans.joined(separator: "\n")))
    }

    /// Exécute une action confirmée et renvoie une ligne de bilan.
    private func executer(_ intention: IntentionAssistant) throws -> String? {
        let stock = StockService(contexte: contexte)
        let transfert = TransfertService(contexte: contexte)

        switch intention {
        case .transfert(let produitID, let sourceID, let destinationID, let quantite):
            guard let produit = produit(produitID),
                  let source = lieu(sourceID),
                  let destination = lieu(destinationID) else { return nil }
            try transfert.transferer(produit: produit, de: source, vers: destination, quantite: quantite)
            return "\(produit.nom) : \(source.nom) \(produit.stock(dans: source)) · \(destination.nom) \(produit.stock(dans: destination))"

        case .usage(let produitID, let lieuID, let quantite):
            guard let produit = produit(produitID),
                  let lieu = lieuID.flatMap(lieu) ?? lieuLePlusFourni(pour: produit) else { return nil }
            try stock.retirerStock(produit: produit, lieu: lieu, quantite: quantite, motif: .usage)
            return "\(produit.nom) : reste \(produit.stockTotal) au total"

        case .reception(let produitID, let lieuID, let quantite):
            guard let produit = produit(produitID),
                  let lieu = lieuID.flatMap(lieu) ?? lieux.first(where: { !$0.estSurMoi }) else { return nil }
            try stock.ajouterStock(produit: produit, lieu: lieu, quantite: quantite, motif: .reception)
            return "\(produit.nom) rangé dans \(lieu.nom) : \(produit.stockTotal) au total"

        default:
            return nil
        }
    }

    private func annuler(messageID: UUID) {
        retirerAction(messageID: messageID)
        messages.append(MessageChat(role: .assistant, texte: "D'accord, j'annule — rien n'a bougé."))
    }

    private func retirerAction(messageID: UUID) {
        if let index = messages.firstIndex(where: { $0.id == messageID }) {
            messages[index].actions = nil
        }
    }

    private func reponseStock(_ produitID: UUID) -> String {
        guard let produit = produit(produitID) else { return "Produit introuvable." }
        let detail = lieux
            .map { ($0.nom, produit.stock(dans: $0)) }
            .filter { $0.1 > 0 }
            .map { "\($0.0) : \($0.1)" }
            .joined(separator: " · ")
        return "Il te reste \(produit.stockTotal) × \(produit.nom)\(detail.isEmpty ? "." : " — \(detail)")"
    }

    // MARK: - Accès données

    private func produit(_ id: UUID) -> Produit? {
        produits.first { $0.id == id }
    }

    private func lieu(_ id: UUID) -> Lieu? {
        lieux.first { $0.id == id }
    }

    private func lieuLePlusFourni(pour produit: Produit) -> Lieu? {
        lieux.filter { produit.stock(dans: $0) > 0 }
            .max { produit.stock(dans: $0) < produit.stock(dans: $1) }
    }

    private func nomProduit(_ id: UUID) -> String {
        produit(id)?.nom ?? "?"
    }

    private func nomLieu(_ id: UUID) -> String {
        lieu(id)?.nom ?? "?"
    }
}
