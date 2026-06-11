# 🐿️ Cachette — Fiche Besoin

> **Statut :** v1 du cadrage — prête pour développement
> **Plateforme cible :** iOS (iPhone), Swift / SwiftUI
> **Architecture :** 100 % locale, sans back-end
> **Auteur du cadrage :** Maxence

---

## 1. Pitch

**Cachette** aide les personnes ayant un traitement ou du matériel médical récurrent à **ne jamais tomber à court**, en gérant leur stock réparti sur plusieurs lieux et en gardant leurs ordonnances toujours sur elles.

La métaphore : un écureuil planque ses provisions dans plusieurs cachettes (chez soi, chez les parents, chez le/la partenaire…). Cachette fait pareil avec ton matériel : elle sait ce que tu as, où, et combien il t'en reste — et te prévient **avant** la rupture ou la péremption.

Une mascotte écureuil (« Cachette ») vit dans toute l'app et porte le ton : doux, rassurant, jamais anxiogène.

---

## 2. Énoncé du problème

Les personnes atteintes d'une condition chronique (diabète, asthme, allergies sévères, etc.) accumulent du matériel et des traitements répartis sur plusieurs lieux de vie. Trois douleurs concrètes :

1. **La rupture de stock** — se rendre compte trop tard qu'il ne reste plus assez d'insuline / de cathéters / de stylos.
2. **La péremption** — du matériel ou des traitements (l'insuline notamment) qui périment sans qu'on s'en aperçoive.
3. **L'ordonnance jamais sous la main** — devoir la retrouver en urgence chez le pharmacien, en voyage, aux urgences.

Aujourd'hui c'est géré « de tête », dans des notes éparses ou pas géré du tout. Le coût : stress, déplacements en urgence, gâchis, et un vrai risque santé en cas de rupture.

**Origine :** besoin réel identifié pour une personne diabétique, généralisable à toute condition à matériel/traitement récurrent ainsi qu'aux aidants.

---

## 3. Objectifs (Goals)

- **Zéro rupture subie** : l'utilisateur est alerté avant de tomber à court, par produit et par lieu.
- **Zéro péremption oubliée** : alerte avant la date de péremption des lots concernés.
- **Ordonnance toujours accessible** : un coffre numérique local, consultable hors-ligne, protégé.
- **Saisie sans friction** : ajouter un produit doit prendre quelques secondes (scan plutôt que saisie manuelle).
- **Confiance maximale** : aucune donnée de santé ne quitte le téléphone par défaut.

## 3.bis Indicateurs de succès

**Indicateurs avancés (rapides)**
- L'utilisateur saisit son stock initial sur ≥ 1 lieu lors de la 1re semaine (activation).
- Un ajout via scan prend < 10 s du lancement caméra à l'item enregistré.
- L'app est rouverte ≥ 1×/semaine (rétention liée aux alertes).

**Indicateurs retard (lents)**
- Réduction des ruptures vécues (auto-déclaré).
- Rétention à 1 mois.
- Pour une éventuelle version publique : note App Store, mises en avant « confidentialité ».

---

## 4. Cibles (Personas)

1. **La personne concernée** — gère son propre stock et ses ordonnances sur plusieurs lieux. *Persona principal de validation : diabète.*
2. **L'aidant·e** — gère le stock d'un proche (enfant, parent âgé). Profil important, à ne pas fermer architecturalement.
3. **Toute condition chronique** — l'app est **agnostique de la pathologie** : un « produit » est générique (nom, type, quantité, lieu, péremption).

---

## 5. Périmètre — Non-Goals (hors scope explicite)

- ❌ **Aucun conseil médical.** Pas de dose, pas de posologie recommandée, pas d'alerte « injecte / prends ton traitement maintenant ». Cachette est un **outil d'inventaire**, pas un dispositif médical. *(Garde-fou juridique majeur : évite le statut de Dispositif Médical et ses obligations.)*
- ❌ **Pas de mesure de glycémie ni de connexion à un capteur/pompe.** Hors sujet pour cette app.
- ❌ **Pas de compte utilisateur, pas de back-end, pas de cloud éditeur.** (cf. §8)
- ❌ **Pas de comptage automatique d'objets en vrac par photo** (peu fiable sur du matériel médical → casse la confiance). On remplace par scan + saisie assistée.
- ❌ **Pas d'Android en v1** (à prévoir plus tard, cf. §11).

---

## 6. User Stories

**Inventaire multi-lieux**
- En tant qu'utilisateur, je veux créer mes lieux (Chez moi, Chez mes parents, Chez X…) afin de répartir mon stock comme dans la vraie vie.
- En tant qu'utilisateur, je veux voir d'un coup d'œil ce que j'ai sur chaque lieu **et** mon stock total, afin de savoir où je me situe.
- En tant qu'utilisateur, je veux ajuster une quantité en un geste (j'ai utilisé / j'ai reçu) afin que le stock reste à jour sans effort.

**Saisie assistée (scan & OCR)**
- En tant qu'utilisateur, je veux scanner le code (Datamatrix) d'une boîte de médicament afin qu'elle soit reconnue et ajoutée sans tout taper.
- En tant qu'utilisateur, je veux photographier une date de péremption afin qu'elle soit lue et rattachée automatiquement au lot.
- En tant qu'utilisateur, je veux photographier une ordonnance afin que les produits prescrits pré-remplissent mon inventaire.

**Alertes**
- En tant qu'utilisateur, je veux être prévenu quand un produit passe sous un seuil que j'ai défini, afin de commander avant la rupture.
- En tant qu'utilisateur, je veux être prévenu avant la péremption d'un lot, afin de l'utiliser ou le remplacer à temps.

**Coffre à documents**
- En tant qu'utilisateur, je veux stocker mes ordonnances (photo/PDF) localement afin de les avoir toujours sur moi, hors-ligne.
- En tant qu'utilisateur, je veux protéger l'accès au coffre par Face ID afin que mes données de santé restent privées.

**Cas limites / états**
- Quand un produit n'a pas de code reconnu, je peux le saisir manuellement.
- Quand l'OCR Apple échoue ou que mon iPhone ne gère pas l'IA embarquée, je peux (option) activer Gemini avec ma propre clé.
- Quand un lieu est vide, l'écran me guide pour ajouter mon premier produit (empty state porté par la mascotte).

---

## 7. Exigences fonctionnelles

### P0 — Must-have (le MVP)

**P0-1 · Gestion des lieux**
- [ ] Créer / renommer / supprimer un lieu (nom, emoji/couleur, type : Domicile / Parents / Travail / Autre).
- [ ] Au moins un lieu par défaut à l'installation.
- [ ] Un lieu spécial **« Sur moi »** (sac / trousse qui voyage avec l'utilisateur), présent par défaut, non supprimable.

**P0-2 · Catalogue & stock**
- [ ] Créer un produit générique : nom, type (insuline, seringue, cathéter, bandelette, médicament, autre), conditionnement (nb d'unités/boîte), photo optionnelle.
- [ ] Affecter une quantité d'un produit à un lieu.
- [ ] Vue « par lieu » et vue « stock total » (somme tous lieux).
- [ ] Ajustement rapide +/− et action « j'ai utilisé » / « j'ai reçu ».
- Critère : *Given un produit à 3 unités sur « Chez moi », When je fais « −1 », Then le stock affiche 2 immédiatement et l'historique enregistre le mouvement.*

**P0-2b · Transfert entre lieux (« Je pars avec… »)**
- [ ] Déplacer une quantité d'un produit d'un lieu source vers un autre (ex. « Chez mes parents » → « Sur moi »), ce qui **décrémente la source** et **incrémente la destination** en une seule opération.
- [ ] Flux type : « Je pars de [réserve] avec [N] [produit] sur moi » → N retirés de la réserve et ajoutés à « Sur moi ».
- [ ] À l'arrivée : dépose depuis « Sur moi » vers le lieu d'accueil (même mécanique, sens inverse).
- [ ] Chaque transfert journalisé comme **deux Mouvements liés** (sortie + entrée).
- Critère : *Given 10 stylos sur « Chez mes parents », When je pars avec 3 sur moi, Then « Chez mes parents » affiche 7 et « Sur moi » affiche 3, et l'historique montre le transfert.*

**P0-3 · Lots & péremption**
- [ ] Un produit peut avoir une ou plusieurs lignes de lot avec une date de péremption optionnelle.
- [ ] Saisie manuelle de la date OU via OCR (P0-5).

**P0-4 · Scan code-barres / Datamatrix (CIP13)**
- [ ] Lecture du Datamatrix d'une boîte via la caméra (Apple Vision, local).
- [ ] Résolution CIP13 → nom du produit via base **BDPM** embarquée localement (SQLite read-only bundlé ou téléchargé au 1er lancement).
- [ ] Si non trouvé : bascule sur saisie manuelle pré-remplie avec le code lu.
- Critère : *Given une boîte avec Datamatrix valide, When je scanne, Then le produit est reconnu (nom BDPM) et proposé à l'ajout en 1 tap.*

**P0-5 · OCR date de péremption**
- [ ] Photographier une zone de texte → extraction de date via Apple Vision (local, gratuit, hors-ligne).
- [ ] Date proposée à validation avant rattachement au lot.

**P0-6 · Alertes locales**
- [ ] Seuil de stock bas configurable **par produit** → notification locale quand le total passe sous le seuil.
- [ ] Fenêtre de péremption configurable (ex. 30 j) → notification locale par lot concerné.
- [ ] Implémentation via notifications locales (aucun serveur de push).
- Critère : *Given un seuil de 5 et un stock de 6, When je passe à 4, Then une notification locale « stock bas » est programmée/déclenchée.*

**P0-7 · Coffre à documents**
- [ ] Ajouter un document (photo prise dans l'app ou import PDF/image) : type (Ordonnance / Compte-rendu / Autre), titre, date.
- [ ] Stockage **local chiffré** (Data Protection iOS), consultable hors-ligne.
- [ ] Verrou Face ID / code optionnel pour ouvrir le coffre.
- [ ] Recherche par titre/type/date.

**P0-8 · Mascotte & ton**
- [ ] Mascotte « Cachette » présente dans les écrans clés, avec ≥ 3 états visuels selon la situation (sereine / vigilante / alerte).
- [ ] Empty states et onboarding portés par la mascotte, ton doux et rassurant.

### P1 — Nice-to-have (fast-follow)

**P1-1 · OCR ordonnance → pré-remplissage**
- Photographier une ordonnance → extraction structurée des produits prescrits, proposés à l'ajout au catalogue.
- **Moteur par défaut : Apple Foundation Models on-device** (guided generation `@Generable` → données typées), si l'appareil est compatible Apple Intelligence (iPhone 15 Pro et +).
- **Renfort optionnel : Gemini (BYO key)** — cf. P1-2.

**P1-2 · IA en ligne optionnelle (fournisseur au choix, clé perso)**
- Dans les réglages, l'utilisateur choisit un **fournisseur** parmi ceux qui font de l'OCR / vision multimodale — **Gemini (Google)**, **Mistral**, **OpenAI** — et colle **sa propre clé API**, stockée en **Keychain** (jamais dans le code, jamais transmise à un éditeur tiers).
- Architecture **provider-agnostique** : une couche d'abstraction `OCRProvider` (interface commune image → texte/structure) avec une implémentation par fournisseur, pour en ajouter d'autres facilement.
- N'est sollicité **que** si l'OCR/structuration Apple échoue ou n'est pas disponible sur l'appareil.
- Consentement explicite : prévenir que l'image/texte de l'ordonnance transitera vers le fournisseur choisi, sous la responsabilité et la clé de l'utilisateur.
- Sans clé : l'app reste pleinement fonctionnelle en mode local (Apple Vision / Foundation Models).

**P1-3 · Assistant « Je pars » (au-dessus du transfert P0-2b)**
- Choisir une destination + une durée → l'app **estime les besoins** sur la période et indique si le stock sur place suffit ; sinon elle **pré-remplit le transfert** avec les quantités à emporter (checklist de départ en 1 tap). *Couche intelligente au-dessus du transfert manuel ; feature différenciante liée au multi-lieux.*

**P1-4 · Mascotte vivante**
- Mascotte animée qui réagit à l'état des réserves et **se déplace visuellement** quand l'utilisateur change de lieu actif. Gamification douce : entretenir ses réserves, c'est garnir les cachettes de la mascotte. Détails dans le *Brief de Direction Artistique*.

### P2 — Future Considerations (à ne pas fermer architecturalement)

- **Suivi de consommation + prédiction** : à partir de l'historique des mouvements, estimer « rupture probable le … ».
- **Sync multi-appareils** via iCloud / CloudKit base privée (toujours sans back-end éditeur).
- **Partage aidant** : un proche peut consulter / contribuer à un stock (opt-in, données de santé → prudence).
- **Renouvellement d'ordonnance** : rappel basé sur la date de validité.
- **Export PDF** d'un récap de stock (pour le médecin / la pharmacie).
- **Android.**

---

## 8. Architecture & contraintes techniques

**Principe directeur : tout vit dans l'app. Aucun back-end, aucun compte, aucune collecte par l'éditeur.**

| Brique | Choix recommandé | Notes |
|---|---|---|
| UI | SwiftUI | iOS-first |
| Cible OS | iOS 26+ | requis pour Foundation Models (P1) ; le cœur P0 peut viser plus bas si besoin |
| Persistance | **SwiftData** | modèle objet natif ; stockage local |
| Base médicaments | **BDPM** (open data FR) en SQLite read-only | snapshot embarqué + refresh mensuel en tâche de fond ; résolution CIP13 → produit, hors-ligne ; API en ligne en fallback |
| Codes-barres / Datamatrix | **Vision** (`DataScannerViewController` / `VNDetectBarcodesRequest`) | local |
| OCR | **Vision** (`VNRecognizeTextRequest`) | local, gratuit, par défaut |
| Structuration IA (P1) | **Foundation Models** on-device (`@Generable`) | sur appareil compatible Apple Intelligence |
| IA en ligne (P1, option) | **Fournisseur au choix** (Gemini / Mistral / OpenAI) via clé perso en **Keychain** | couche `OCRProvider` pluggable ; appel direct depuis l'app, opt-in, jamais par défaut |
| Documents | sandbox app + **Data Protection** (chiffrement) + verrou Face ID | hors-ligne |
| Alertes | **UNUserNotificationCenter** (notifications locales) | aucun push serveur |

**Dégradation gracieuse :** scan code-barres + OCR (Vision) fonctionnent largement ; la structuration « intelligente » d'ordonnance (LLM) s'active sur appareils récents, sinon saisie assistée manuelle. Aucune feature P0 ne dépend du LLM.

---

## 9. Modèle de données (indicatif)

- **Lieu** : `id`, `nom`, `type`, `couleur/emoji`.
- **Produit** : `id`, `nom`, `type`, `cip13?`, `conditionnement` (unités/boîte), `photo?`, `seuilStockBas?`, `refBDPM?`.
- **Lot** (ligne de stock) : `id`, `produit`, `lieu`, `quantité`, `datePeremption?`, `dateAjout`.
- **Mouvement** (P2-ready, à modéliser dès le départ) : `id`, `lot/produit`, `lieu`, `delta`, `date`, `motif` (usage/réception).
- **Document** : `id`, `type` (Ordonnance/CR/Autre), `titre`, `fichier` (image/pdf chiffré), `date`, `dateValidité?`, `produitsLiés?`.
- **Réglages** : seuils par défaut, fenêtre de péremption, fournisseur IA + clé API (Keychain), verrou Face ID on/off.

---

## 10. Garde-fous (obligatoires)

1. **Frontière non-médicale.** Aucune dose, aucune reco de traitement, aucune injonction temporelle de prise. Mention claire « Cachette est un outil d'inventaire, pas un dispositif médical ni un avis médical ». Conditionne la conformité réglementaire et la validation App Store.
2. **RGPD / données de santé.** Données sensibles, traitées **exclusivement en local**, chiffrées, sans collecte par l'éditeur, sans compte. Si l'utilisateur active un fournisseur IA en ligne (Gemini / Mistral / OpenAI) : consentement explicite + information que les données partent vers le fournisseur choisi sous sa clé/responsabilité. Politique de confidentialité et nutrition label App Store à préparer en conséquence.

---

## 11. Questions ouvertes

- ✅ **[Résolu — BDPM]** Fichiers BDPM très légers (TSV texte, quelques Mo, mise à jour mensuelle). **Décision : embarquer un snapshot récent dans l'app** (scan opérationnel dès le 1er lancement, hors-ligne), puis **rafraîchir en tâche de fond** ~1×/mois. API REST en ligne uniquement en *fallback* pour un médicament très récent absent du snapshot local.
- **[Légal]** Formulation exacte des disclaimers + politique de confidentialité — à valider avant publication App Store. *(bloquant pour publication, pas pour le proto)*
- **[Produit]** Le « Mode Je pars » (P1-3) entre-t-il au MVP ou en premier fast-follow ?
- **[Technique]** Cible OS minimale du cœur P0 (compromis entre couverture d'appareils et simplicité).
- **[Design]** Direction artistique de la mascotte (style, jeu d'états) — à briefer.

---

## 12. Phasage suggéré

- **MVP (P0)** : lieux + catalogue/stock + lots/péremption + scan CIP13 (BDPM) + OCR date + alertes locales + coffre documents + mascotte. → app pleinement utile, 100 % locale.
- **Fast-follow (P1)** : OCR ordonnance (Foundation Models, + option Gemini BYO key) + Mode « Je pars ».
- **Plus tard (P2)** : prédiction de rupture, sync iCloud, partage aidant, export PDF, Android.

---

## 13. Brief de démarrage pour l'agent de code

> Construis une app **iOS / SwiftUI** nommée **Cachette**, **100 % locale, sans back-end ni compte**.
> Commence par le **MVP (§7 P0)** : modèle de données SwiftData (§9), gestion des lieux (dont le lieu spécial **« Sur moi »**), catalogue/stock multi-lieux avec ajustement rapide, **transfert entre lieux** (« je pars avec N »), lots + dates de péremption, **scan Datamatrix via Vision + résolution CIP13 sur BDPM locale**, **OCR de date via Vision**, **alertes locales** (stock bas par produit + péremption), et **coffre à documents chiffré** avec verrou Face ID.
> Intègre dès le départ l'entité **Mouvement** (pour préparer la prédiction P2) et une **mascotte écureuil** à états (sereine / vigilante / alerte) sur les écrans clés et empty states.
> N'implémente l'IA d'ordonnance (Foundation Models on-device, puis fournisseur en ligne au choix — Gemini / Mistral / OpenAI — via une couche `OCRProvider` pluggable et clé en Keychain) **qu'en P1** — aucune feature P0 ne doit en dépendre.
> Respecte les **garde-fous §10** : aucun conseil médical, données de santé strictement locales et chiffrées.
