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
        /// Action en attente de confirmation, portée par ce message.
        var action: IntentionAssistant?
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                conversation
                barreSaisie
            }
            .fondCachette()
            .navigationTitle("Assistant")
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
                if let action = message.action {
                    HStack {
                        Button("Confirmer") {
                            confirmer(action, messageID: message.id)
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
        VStack(spacing: 4) {
            if let erreur = dictee.messageErreur {
                Text(erreur)
                    .font(CachetteTypography.legende)
                    .foregroundStyle(CachetteColors.terracotta)
            }
            HStack(spacing: 10) {
                TextField(
                    dictee.enEcoute ? "Je t'écoute…" : "Écris ou dicte ta phrase…",
                    text: $saisie,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .focused($champFocalise)
                .onSubmit { envoyer() }

                Button {
                    dictee.basculer()
                } label: {
                    Image(systemName: dictee.enEcoute ? "mic.fill" : "mic")
                        .font(.title2)
                        .foregroundStyle(dictee.enEcoute ? CachetteColors.terracotta : CachetteColors.rouxCachette)
                        .symbolEffect(.pulse, isActive: dictee.enEcoute)
                }
                .accessibilityLabel(dictee.enEcoute ? "Arrêter la dictée" : "Dicter")

                Button {
                    envoyer()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(CachetteColors.rouxCachette)
                }
                .disabled(saisie.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Envoyer")
            }
            .padding(12)
        }
        .background(.thinMaterial)
    }

    // MARK: - Logique

    private func envoyer() {
        let phrase = saisie.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }
        saisie = ""
        messages.append(MessageChat(role: .utilisateur, texte: phrase))

        let intention = CommandeInterpreteur.interpreter(
            phrase,
            produits: produits.map { ProduitRef(id: $0.id, nom: $0.nom) },
            lieux: lieux.map { LieuRef(id: $0.id, nom: $0.nom, estSurMoi: $0.estSurMoi) }
        )

        switch intention {
        case .stock(let produitID):
            messages.append(MessageChat(role: .assistant, texte: reponseStock(produitID)))
        case .incomprise(let raison):
            messages.append(MessageChat(role: .assistant, texte: "🤔 \(raison)"))
        default:
            messages.append(MessageChat(
                role: .assistant,
                texte: resume(intention),
                action: intention
            ))
        }
    }

    private func resume(_ intention: IntentionAssistant) -> String {
        switch intention {
        case .transfert(let produitID, let sourceID, let destinationID, let quantite):
            "🚚 Je transfère \(quantite) × \(nomProduit(produitID)) de \(nomLieu(sourceID)) vers \(nomLieu(destinationID)). Je confirme ?"
        case .usage(let produitID, let lieuID, let quantite):
            "✏️ Je retire \(quantite) × \(nomProduit(produitID))\(lieuID.map { " de \(nomLieu($0))" } ?? "") (utilisé). Je confirme ?"
        case .reception(let produitID, let lieuID, let quantite):
            "📦 J'ajoute \(quantite) × \(nomProduit(produitID))\(lieuID.map { " dans \(nomLieu($0))" } ?? ""). Je confirme ?"
        default:
            ""
        }
    }

    private func confirmer(_ intention: IntentionAssistant, messageID: UUID) {
        retirerAction(messageID: messageID)
        let stock = StockService(contexte: contexte)
        let transfert = TransfertService(contexte: contexte)

        do {
            switch intention {
            case .transfert(let produitID, let sourceID, let destinationID, let quantite):
                guard let produit = produit(produitID),
                      let source = lieu(sourceID),
                      let destination = lieu(destinationID) else { return }
                try transfert.transferer(produit: produit, de: source, vers: destination, quantite: quantite)
                messages.append(MessageChat(
                    role: .assistant,
                    texte: "C'est fait ! \(nomLieu(sourceID)) : \(produit.stock(dans: source)) · \(nomLieu(destinationID)) : \(produit.stock(dans: destination)) 🐿️"
                ))

            case .usage(let produitID, let lieuID, let quantite):
                guard let produit = produit(produitID),
                      let lieu = lieuID.flatMap(lieu) ?? lieuLePlusFourni(pour: produit) else { return }
                try stock.retirerStock(produit: produit, lieu: lieu, quantite: quantite, motif: .usage)
                messages.append(MessageChat(
                    role: .assistant,
                    texte: "Noté ! Il reste \(produit.stockTotal) × \(produit.nom) au total."
                ))

            case .reception(let produitID, let lieuID, let quantite):
                guard let produit = produit(produitID),
                      let lieu = lieuID.flatMap(lieu) ?? lieux.first(where: { !$0.estSurMoi }) else { return }
                try stock.ajouterStock(produit: produit, lieu: lieu, quantite: quantite, motif: .reception)
                messages.append(MessageChat(
                    role: .assistant,
                    texte: "Rangé dans \(lieu.nom) ! Stock total : \(produit.stockTotal) × \(produit.nom) 🎉"
                ))

            default:
                break
            }
        } catch {
            messages.append(MessageChat(role: .assistant, texte: "❌ \(error.localizedDescription)"))
        }
    }

    private func annuler(messageID: UUID) {
        retirerAction(messageID: messageID)
        messages.append(MessageChat(role: .assistant, texte: "D'accord, j'annule — rien n'a bougé."))
    }

    private func retirerAction(messageID: UUID) {
        if let index = messages.firstIndex(where: { $0.id == messageID }) {
            messages[index].action = nil
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
