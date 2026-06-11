import Foundation
import SwiftData

nonisolated enum TypeProduit: String, Codable, CaseIterable, Identifiable {
    case insuline
    case seringue
    case catheter
    case bandelette
    case medicament
    case autre

    var id: String { rawValue }

    var libelle: String {
        switch self {
        case .insuline: "Insuline"
        case .seringue: "Seringue / stylo"
        case .catheter: "Cathéter"
        case .bandelette: "Bandelette / capteur"
        case .medicament: "Médicament"
        case .autre: "Autre"
        }
    }

    var symbole: String {
        switch self {
        case .insuline: "💉"
        case .seringue: "🖊️"
        case .catheter: "🩹"
        case .bandelette: "🩸"
        case .medicament: "💊"
        case .autre: "📦"
        }
    }
}

@Model
final class Produit {
    @Attribute(.unique) var id: UUID
    var nom: String
    var typeRaw: String
    /// Code CIP13 si le produit vient d'un scan de boîte française.
    var cip13: String?
    /// Code CIS de la BDPM (référence stable du médicament).
    var refBDPMCIS: String?
    /// Nombre d'unités par boîte (1 = produit à l'unité).
    var conditionnement: Int
    @Attribute(.externalStorage) var photoData: Data?
    /// Seuil sous lequel on alerte « stock bas ». nil = pas d'alerte.
    var seuilStockBas: Int?
    var dateCreation: Date

    @Relationship(deleteRule: .cascade, inverse: \Lot.produit)
    var lots: [Lot] = []

    @Relationship(deleteRule: .nullify, inverse: \Mouvement.produit)
    var mouvements: [Mouvement] = []

    var documents: [DocumentItem] = []

    var type: TypeProduit {
        get { TypeProduit(rawValue: typeRaw) ?? .autre }
        set { typeRaw = newValue.rawValue }
    }

    /// Stock total tous lieux confondus. (Propriété calculée — jamais dans un #Predicate.)
    var stockTotal: Int {
        lots.reduce(0) { $0 + $1.quantite }
    }

    func stock(dans lieu: Lieu) -> Int {
        lots.filter { $0.lieu?.id == lieu.id }.reduce(0) { $0 + $1.quantite }
    }

    init(
        nom: String,
        type: TypeProduit = .autre,
        cip13: String? = nil,
        refBDPMCIS: String? = nil,
        conditionnement: Int = 1,
        seuilStockBas: Int? = nil
    ) {
        self.id = UUID()
        self.nom = nom
        self.typeRaw = type.rawValue
        self.cip13 = cip13
        self.refBDPMCIS = refBDPMCIS
        self.conditionnement = max(1, conditionnement)
        self.seuilStockBas = seuilStockBas
        self.dateCreation = .now
    }
}
