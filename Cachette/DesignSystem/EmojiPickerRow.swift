import SwiftUI

/// Sélecteur d'emoji compact : palette rapide + champ libre.
struct EmojiPickerRow: View {
    @Binding var emoji: String

    private static let palette = ["💊", "💉", "🩹", "🩸", "🪡", "📟", "🌬️", "⚡", "🍬", "📦"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Self.palette, id: \.self) { candidat in
                        Text(candidat)
                            .font(.title3)
                            .frame(width: 38, height: 38)
                            .background(
                                candidat == emoji ? CachetteColors.rouxCachette.opacity(0.2) : Color(.secondarySystemBackground),
                                in: .rect(cornerRadius: 8)
                            )
                            .onTapGesture { emoji = candidat }
                    }
                    TextField("✏️", text: $emoji)
                        .frame(width: 44, height: 38)
                        .multilineTextAlignment(.center)
                        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 8))
                        .onChange(of: emoji) { _, nouveau in
                            // On ne garde que le dernier caractère (un emoji).
                            if nouveau.count > 1 {
                                emoji = String(nouveau.suffix(1))
                            }
                        }
                }
            }
        }
    }
}
