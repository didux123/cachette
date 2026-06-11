import SwiftUI
import TipKit

/// Tour guidé du premier lancement : des coachmarks TipKit qui s'affichent
/// une fois chacun, au fil de la découverte des écrans.

struct TipAjouter: Tip {
    var title: Text { Text("Ajoute ou réapprovisionne") }
    var message: Text? {
        Text("« J'ai reçu » pour un réassort en un tap depuis ta liste, ou crée un nouveau produit à suivre.")
    }
    var image: Image? { Image(systemName: "plus.circle.fill") }
}

struct TipJePars: Tip {
    var title: Text { Text("Tu pars quelque part ?") }
    var message: Text? {
        Text("Dis-moi où et combien de temps : j'estime ce qu'il faut emporter selon ta consommation réelle.")
    }
    var image: Image? { Image(systemName: "figure.walk.departure") }
}

struct TipPucesLieux: Tip {
    var title: Text { Text("Tes cachettes") }
    var message: Text? {
        Text("Passe d'un lieu à l'autre d'un tap. « Total » montre tout ton stock, tous lieux confondus.")
    }
    var image: Image? { Image(systemName: "map.fill") }
}

struct TipPlusMoins: Tip {
    var title: Text { Text("Le geste du quotidien") }
    var message: Text? {
        Text("− quand tu utilises, + quand tu ranges. Choisis un lieu pour que les boutons apparaissent, et appuie sur un produit pour le détail.")
    }
    var image: Image? { Image(systemName: "plusminus.circle.fill") }
}

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
