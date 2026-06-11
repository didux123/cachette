import SwiftUI
import TipKit

/// Coachmarks TipKit pour les onglets que le tuto interactif de l'inventaire
/// ne couvre pas — affichés une fois chacun.

struct TipScanner: Tip {
    var title: Text { Text("Le plus rapide : scanner") }
    var message: Text? {
        Text("Vise le petit carré d'une boîte de médicament : nom, péremption et n° de lot sont remplis tout seuls.")
    }
    var image: Image? { Image(systemName: "barcode.viewfinder") }
}

struct TipCoffre: Tip {
    var title: Text { Text("Tes documents, toujours sur toi") }
    var message: Text? {
        Text("Range ici ordonnances et comptes-rendus : chiffrés sur ton téléphone, lisibles même sans réseau.")
    }
    var image: Image? { Image(systemName: "lock.doc.fill") }
}
