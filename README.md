# 🐿️ Cachette

App iOS (SwiftUI / SwiftData) d'inventaire de matériel médical multi-lieux pour personnes avec traitement chronique. **100 % locale, sans back-end, sans compte.**

> ⚠️ Cachette est un outil d'inventaire — **pas un dispositif médical ni un avis médical**.

## Specs

- [Fiche besoin](Cachette_Fiche_Besoin.md) — cadrage produit complet (P0/P1/P2)
- [Brief direction artistique mascotte](Cachette_Brief_Direction_Artistique_Mascotte.md)

## Développement

Prérequis : Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate          # génère Cachette.xcodeproj depuis project.yml
open Cachette.xcodeproj
```

Build & tests en CLI :

```bash
xcodebuild build -scheme Cachette -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -scheme Cachette -destination 'platform=iOS Simulator,name=iPhone 17'
```

Régénérer la base médicaments BDPM embarquée :

```bash
python3 Tools/bdpm_build.py    # produit Cachette/Resources/bdpm.sqlite
```
