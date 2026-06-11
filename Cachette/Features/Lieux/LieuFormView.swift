import SwiftUI
import SwiftData

/// Création (lieu == nil) ou édition d'un lieu.
struct LieuFormView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var dismiss

    let lieu: Lieu?

    @State private var nom = ""
    @State private var type: TypeLieu = .domicile
    @State private var emoji = "🏠"
    @State private var couleurHex = "C8643C"

    private static let emojis = ["🏠", "👨‍👩‍👧", "💼", "🎒", "🏡", "🏢", "🚗", "⛺️", "❤️", "📦"]
    private static let couleurs = ["C8643C", "7FA67E", "E2A33C", "D2705B", "5B4636", "6E8CA0"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom") {
                    TextField("Chez mes parents…", text: $nom)
                }
                if !(lieu?.estSurMoi ?? false) {
                    Section("Type") {
                        Picker("Type", selection: $type) {
                            ForEach(TypeLieu.allCases.filter { $0 != .surMoi }) { type in
                                Text(type.libelle).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                Section("Emoji") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5)) {
                        ForEach(Self.emojis, id: \.self) { e in
                            Text(e)
                                .font(.title2)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(
                                    e == emoji ? CachetteColors.rouxCachette.opacity(0.2) : .clear,
                                    in: .rect(cornerRadius: 8)
                                )
                                .onTapGesture { emoji = e }
                        }
                    }
                }
                Section("Couleur") {
                    HStack {
                        ForEach(Self.couleurs, id: \.self) { hex in
                            Circle()
                                .fill(Color(hexString: hex))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if hex == couleurHex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { couleurHex = hex }
                        }
                    }
                }
            }
            .navigationTitle(lieu == nil ? "Nouveau lieu" : "Modifier le lieu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { enregistrer() }
                        .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let lieu {
                    nom = lieu.nom
                    type = lieu.type
                    emoji = lieu.emoji
                    couleurHex = lieu.couleurHex
                }
            }
        }
    }

    private func enregistrer() {
        let nomPropre = nom.trimmingCharacters(in: .whitespaces)
        do {
            if let lieu {
                lieu.nom = nomPropre
                if !lieu.estSurMoi { lieu.type = type }
                lieu.emoji = emoji
                lieu.couleurHex = couleurHex
                try contexte.save()
            } else {
                try StockService(contexte: contexte)
                    .creerLieu(nom: nomPropre, type: type, emoji: emoji, couleurHex: couleurHex)
            }
            dismiss()
        } catch {
            // L'enregistrement local échoue rarement ; on garde la feuille ouverte.
        }
    }
}
