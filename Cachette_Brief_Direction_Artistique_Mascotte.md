# 🐿️ Cachette — Brief de Direction Artistique (Mascotte)

> Compagnon de l'app Cachette. À transmettre à un·e illustrateur·rice / motion designer, et à l'agent de code pour l'intégration.

---

## 1. Intention

La mascotte **Cachette** est un **petit écureuil** qui veille sur les réserves de l'utilisateur. Elle incarne la promesse de l'app : *« tu as toujours ce qu'il faut, je garde un œil dessus »*.

Ton : **doux, attentif, rassurant — jamais anxiogène ni culpabilisant.** On est dans un contexte de santé : la mascotte est une présence bienveillante, pas une alarme stressante ni un coach qui réprimande.

Principe fondateur : **entretenir ses réserves = garnir les cachettes de Cachette.** L'utilisateur ne « gère un stock », il prend soin d'un petit compagnon (et de lui-même par ricochet). C'est ça qui donne envie de remplir l'app.

---

## 2. Le personnage

- **Espèce :** écureuil roux stylisé, formes **rondes et douces** (pas anguleux), grande queue touffue, **bajoues** légèrement gonflées (le clin d'œil au stockage).
- **Accessoire signature :** une petite **besace / pochon** qu'il porte en bandoulière — utile narrativement pour les transferts (« je pars avec »).
- **Lisibilité :** doit rester reconnaissable en très petit (icône, badge de notif) comme en grand (onboarding, empty states).
- **Neutralité :** pas de genre marqué, pas d'attribut médical (pas de blouse, pas de croix) — l'app n'est pas un dispositif médical, la mascotte non plus.

**Anti-patterns à éviter**
- ❌ Mascotte « malade » ou souffrante quand le stock est bas (insensible en contexte santé). On reste sur *attentive / vigilante*, jamais *en détresse*.
- ❌ Expressions de reproche, gros yeux tristes culpabilisants, points d'exclamation agressifs.
- ❌ Style trop enfantin/bébé qui décrédibiliserait l'usage adulte et sérieux (gestion de traitement).

---

## 3. Style visuel — 3 pistes (à trancher)

| Piste | Description | Pour / Contre |
|---|---|---|
| **A. Vectoriel « cosy »** *(recommandé)* | Aplats doux, contours arrondis, ombres légères, palette chaude. Type illustration éditoriale moderne. | + Léger, anime bien, scalable, intemporel. − Moins « waou » qu'un 3D. |
| **B. Soft-3D / pâte à modeler** | Rendu volumétrique doux façon claymation. | + Très attachant, premium. − Plus lourd à produire/animer, risque de cliché « app mignonne ». |
| **C. Storybook dessiné main** | Traits crayonnés, texture papier. | + Chaleur, singularité. − Anime moins bien, plus difficile à décliner en états. |

**Reco : Piste A.** Meilleur compromis charme / légèreté / facilité d'animation par états — ce qui colle pile au besoin (mascotte qui réagit + se déplace).

---

## 4. Palette & typo (proposition de tokens)

- **Roux Cachette** `#C8643C` (le pelage, couleur d'accent de la marque)
- **Crème** `#F6EFE3` (fonds doux)
- **Vert sauge** `#7FA67E` (état serein / OK)
- **Ambre** `#E2A33C` (état vigilant)
- **Terracotta douce** `#D2705B` (état alerte — chaud mais pas rouge agressif)
- **Brun noisette** `#5B4636` (textes, contours)

Typo : une **sans-serif ronde et chaleureuse** (ex. style Quicksand / Nunito) pour les titres, lisible et douce. À aligner avec l'UI de l'app.

---

## 5. Système d'états (le cœur du truc)

La mascotte est **pilotée par l'état des réserves**. Une machine à états simple, mappée sur des conditions claires :

| État | Déclencheur | Expression / Pose | Couleur d'ambiance |
|---|---|---|---|
| **Sereine** | Tous stocks ≥ seuils, rien ne périme bientôt | Détendue, assise sur sa réserve pleine, sourire léger | Vert sauge |
| **Vigilante** | Un produit approche du seuil **ou** une péremption dans la fenêtre | Attentive, oreilles dressées, regarde une cachette | Ambre |
| **Alerte** | Stock sous le seuil **ou** lot périmé | Affairée, prépare le pochon (« faut réassort »), **jamais paniquée** | Terracotta |
| **Contente** | L'utilisateur vient de réapprovisionner / scanner un ajout | Petit saut de joie, bajoues pleines | Roux + confettis discrets |
| **En voyage** | Changement de lieu actif / transfert en cours | Court avec son pochon d'une cachette à l'autre | Crème |
| **Au repos** | Inactivité / mode nuit | Roulée en boule, dort | Tons sombres doux |

> Règle d'or : l'état **informe**, il n'**obstrue jamais**. La mascotte ne bloque pas l'écran, ne force pas d'interaction.

---

## 6. La gamification « réserves de la mascotte »

Traduire l'état du stock réel en **garde-manger visuel** de Cachette :

- Chaque **lieu** de l'utilisateur = une **cachette** (un creux d'arbre, un petit terrier) que Cachette entretient.
- Stock sain → la cachette est **garnie de glands/provisions**, Cachette est sereine.
- Stock qui baisse → la cachette se **vide doucement**, Cachette devient vigilante.
- Réassort → animation de **remplissage** satisfaisante (le « pourquoi je remplis l'app » devient gratifiant).

⚠️ **Garde-fou ton santé :** la jauge ne doit jamais virer au catastrophisme. Une cachette qui se vide = « pense à réapprovisionner », pas « tu as échoué ». Pas de compte à rebours anxiogène, pas de rouge clignotant.

---

## 7. Le déplacement entre lieux (ton idée)

Quand l'utilisateur change de lieu actif (ou exécute un transfert « je pars avec… ») :

- Cachette joue une **animation de trajet** : elle attrape son pochon, **détale** hors de la cachette de départ, traverse, et **arrive** dans la cachette de destination.
- Chaque lieu peut avoir une **micro-identité visuelle** (un fond/terrier légèrement différent : « Chez moi », « Chez les parents », « Sur moi » = le pochon lui-même).
- Le lieu **« Sur moi »** est représenté par Cachette **portant le pochon** : tout ce que tu emportes voyage littéralement avec elle. Cohérence parfaite avec la feature de transfert.

C'est l'animation signature de l'app : elle raconte le multi-lieux mieux que n'importe quel texte.

---

## 8. Animation — principes & technique

- **Micro-vie permanente :** respiration légère, clignements, frémissement de queue, même au repos → la mascotte semble vivante sans distraire.
- **Transitions d'état douces :** pas de saut brutal entre serein/alerte ; on glisse.
- **Moments de récompense :** réassort, premier lieu créé, première ordonnance rangée → petites célébrations brèves.
- **Techno recommandée : [Rive](https://rive.app)** — idéal pour un personnage **piloté par machine à états** (exactement notre §5), très léger, runtime natif iOS. **Lottie** en alternative si l'équipe la connaît déjà (bon pour des animations linéaires, moins pour les états).
- **Accessibilité :** respecter **Reduce Motion** (fallback statique par état) ; ne jamais conditionner une info critique à une animation seule.
- **Sobriété batterie/perf :** animations courtes, en pause hors écran.

---

## 9. Où la mascotte apparaît

- **Accueil / dashboard** : présence permanente, reflète l'état global.
- **Empty states** : « Aucune réserve ici pour l'instant — on en crée une ? » porté par Cachette.
- **Onboarding** : Cachette guide la création du 1er lieu et du 1er produit.
- **Moment d'alerte** : notification + écran avec la bonne expression (vigilante/alerte).
- **Flux « Je pars » / transfert** : Cachette prend son pochon.
- **Succès** : scan réussi, réassort, ordonnance ajoutée.

---

## 10. Livrables attendus

1. **Character sheet** : turnaround (face / 3-4 / profil), proportions, do & don't.
2. **Expression / state sheet** : les 6 états du §5 + variantes de récompense.
3. **Machine à états Rive** (`.riv`) prête à câbler, inputs nommés (`stockLevel`, `isTraveling`, `isResting`, `justRestocked`…).
4. **Jeu d'assets statiques** (fallback Reduce Motion + icônes/badges notif).
5. **Tokens de couleur** alignés sur le §4.

---

## 11. Pour l'agent de code

> Intègre la mascotte via **Rive** (runtime iOS), pilotée par une **machine à états** dont les inputs sont dérivés de l'état réel des réserves (niveau de stock vs seuils, péremptions à venir, lieu actif, transfert en cours). Mappe les 6 états du §5. La mascotte est **décorative et informative, jamais bloquante** ; prévois un **fallback statique** si *Reduce Motion* est activé. En MVP, une version réduite (états Sereine / Vigilante / Alerte + empty states) suffit ; le déplacement entre lieux et la gamification des cachettes relèvent du P1-4.
