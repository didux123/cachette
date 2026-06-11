import Foundation

/// Presets de produits à suivre par condition chronique : choisis ta
/// situation et coche, ou construis ta liste à la main. Purement indicatif —
/// l'app reste agnostique de la pathologie (aucun conseil médical).
nonisolated struct SuggestionProduit: Identifiable, Hashable {
    let nom: String
    let emoji: String
    let type: TypeProduit

    var id: String { nom }
}

nonisolated struct ConditionChronique: Identifiable, Hashable {
    let nom: String
    let emoji: String
    let suggestions: [SuggestionProduit]

    var id: String { nom }

    static let toutes: [ConditionChronique] = [
        ConditionChronique(
            nom: "Diabète",
            emoji: "🩸",
            suggestions: [
                SuggestionProduit(nom: "Stylo insuline rapide", emoji: "💉", type: .insuline),
                SuggestionProduit(nom: "Stylo insuline lente", emoji: "💉", type: .insuline),
                SuggestionProduit(nom: "Cathéters de pompe", emoji: "🩹", type: .catheter),
                SuggestionProduit(nom: "Capteurs de glycémie", emoji: "📟", type: .bandelette),
                SuggestionProduit(nom: "Bandelettes", emoji: "🩸", type: .bandelette),
                SuggestionProduit(nom: "Aiguilles de stylo", emoji: "🪡", type: .seringue),
                SuggestionProduit(nom: "Resucrage", emoji: "🍬", type: .autre),
            ]
        ),
        ConditionChronique(
            nom: "Asthme",
            emoji: "🌬️",
            suggestions: [
                SuggestionProduit(nom: "Inhalateur de secours", emoji: "🌬️", type: .medicament),
                SuggestionProduit(nom: "Traitement de fond", emoji: "💊", type: .medicament),
                SuggestionProduit(nom: "Chambre d'inhalation", emoji: "🫁", type: .autre),
            ]
        ),
        ConditionChronique(
            nom: "Allergie sévère",
            emoji: "⚡",
            suggestions: [
                SuggestionProduit(nom: "Stylo d'adrénaline", emoji: "⚡", type: .seringue),
                SuggestionProduit(nom: "Antihistaminiques", emoji: "💊", type: .medicament),
            ]
        ),
        ConditionChronique(
            nom: "Traitement au long cours",
            emoji: "💊",
            suggestions: [
                SuggestionProduit(nom: "Traitement quotidien", emoji: "💊", type: .medicament),
                SuggestionProduit(nom: "Pilulier de secours", emoji: "📦", type: .autre),
            ]
        ),
    ]
}
