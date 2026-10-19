# Reprise : passe visuelle v3

État au 27 septembre 2026, pour une session qui part de zéro.
`verify.sh` exit 0, 737 tests. `ui-pass.sh` vert. **Rien n'est commité ni poussé.**

## Ce que cette session a fait

Une passe de finition visuelle, décidée depuis
[design/04-visual-language-and-surfaces.md](design/04-visual-language-and-surfaces.md)
et le HIG macOS. Le modèle produit, le format `.kollio`, le domaine et le backend
n'ont pas été touchés.

### 1. Le contraste du texte sur l'accent

`ActionButton` faisait `isDefault ? Color.white`. Les deux accents ne sont pas
la même couleur : blanc sur le cobalt clair fait 5,82:1, blanc sur le
periwinkle du thème sombre fait **2,15:1**. Le premier plan est désormais
`Theme.onAccent`, mesuré, et le premier plan sombre est l'encre du canvas
(8,12:1). La palette stocke ses valeurs en hexadécimal pour qu'un ratio soit
calculable dans un test — une `Color` ne se mesure pas sans fenêtre derrière elle.

### 2. Les actions locales

Une plaque blanche dessinée à la main, avec une ombre de 14 points, contenait des
boutons qui dessinaient chacun leur fond. La plaque a disparu : le groupe est un
`GlassEffectContainer`, l'action saillante en `.glassProminent`, les autres en
`.glass`, et le tint ne porte que sur l'action saillante — le teinter toutes
donnait trois pilules bleues identiques.

Le placement n'était plus qu'une supposition : 300 × 52, puis borné, à
l'intérieur de la vue qui choisissait ces nombres. La taille est mesurée et
publiée par une préférence, et `ContextualPlacement.resolve` décide — en
dessous, au-dessus, à droite, à gauche, puis borné. Un cluster plus large que la
fenêtre est centré plutôt que poussé d'un côté.

Sous transparence réduite, les instruments cessent d'être en verre et deviennent
une surface avec bordure : `InstrumentMaterial.resolve` en décide, et c'est le
seul matériau dessiné à la main dans l'application.

### 3. Deux bugs trouvés en regardant, pas en lisant

Les libellés de la barre n'étaient pas localisés : `explore`, `clarify`,
`setAside` en clair dans une fenêtre française, parce que l'énumération renvoyait
la clé sans son namespace et que `String(localized:)` renvoie la clé quand il ne
la trouve pas. Et la barre n'avait aucun identifiant d'accessibilité, alors
qu'`AXID.contextualActions` existait : le groupe était absent de l'arbre
d'accessibilité, donc invisible à VoiceOver.

### 4. La typographie

Six rôles, une famille, quatre en medium — ce qui faisait de medium «
ordinaire » et laissait le texte lu au même poids que les boutons. L'échelle est
désormais une table `TypeRole` → `TypeSpec`, poids comme rang pour être
comparable. L'invitation et la pensée repassent en regular parce qu'elles se
lisent. Le seul semibold est le repère « le sol a bougé ».

### 5. La silhouette des formes

Référence et résultat riche étaient deux rectangles blancs quasi identiques,
séparés par quatre points de rayon et une ombre. `NodeAppearanceTable` décide
maintenant : une pensée n'a pas de surface, une source est un filet, un résultat
riche est un filet plus un filet vertical sur le bord de tête. L'ombre a quitté
la source : le monde est mat.

## Fichiers

Nouveaux : `Canvas/Rendering/NodeAppearance.swift`,
`Canvas/Geometry/ContextualPlacement.swift`, `DesignSystem/InstrumentStyle.swift`,
et quatre suites de tests — `OnAccentContrastTests`, `ContextualPlacementTests`,
`ContextualActionLabelTests`, `TypeScaleTests`, `NodeAppearanceTests`,
`InstrumentMaterialTests`.

Modifiés : `DesignTokens.swift`, `ObjectNodeView.swift`, `ContextualViews.swift`,
`ContextualActionSet.swift`, `ProposalViews.swift`, `Localizable.xcstrings`,
`sync-xcodeproj.py`, les trois manifestes, le projet généré,
`docs/known-limitations.md`, `openspec/specs/evidence.md`.

## Le plancher de déploiement

Il était 14, écrit à quatre endroits, dont `services/KollioServer` qui est dans
le graphe de paquets sans être dans le projet Xcode. Il est maintenant 26.0,
écrit une fois dans `sync-xcodeproj.py` et une fois dans chacun des trois
manifestes, tous en `swift-tools-version: 6.4` parce que `.v26` n'existe pas en
dessous. C'est ce qui rend `.glass` disponible sans repli.

**À confirmer** : « 27 cible, 26 à la limite » a été lu comme plancher 26. Si
c'était 27, c'est une constante à changer et trois manifestes avec.

## Ce qui n'est pas vérifié

- **Aucun rendu sombre n'a jamais été capturé.** Trois voies tentées — argument
  de lancement, apparence globale, domaine de l'application — sans succès. Les
  chiffres sont prouvés, le chemin de rendu est corrigé, personne n'a regardé.
- **Contraste renforcé, transparence réduite, animations réduites** : résolus
  dans `Theme`, lus et non exercés, sauf la transparence réduite qui a maintenant
  sa propre décision testée.
- **La fenêtre étroite** : prouvée par le calcul de placement, pas par une
  capture. XCUITest n'a pas de moyen fiable de redimensionner.
- **Rien n'a été vu par une personne.** La règle du filet vertical sur le
  résultat riche et le rendu des boutons en verre sont des décisions derivées du
  document, pas des observations.
- **L'échelle d'élévation est morte** : `Elevation` est déclaré et lu nulle
  part, pendant que douze vues écrivent leur propre ombre. La couche monde n'en
  a plus ; les ombres restantes sont sur des surfaces transitoires. Balayé à
  l'aveugle serait exactement le genre de remaniement à éviter.

## Outillage de capture, état

Le harnais qui photographiait Kollio est **retiré du dépôt**, et une copie est
dans `/tmp/DesignShot.swift.bak`. Il photographiait l'écran entier, donc le
contenu personnel du second écran, et il était instable. Il ne faut pas le
réintégrer en l'état.

La seule voie correcte serait un plan de test qui désactive les captures
automatiques, ce qui débloquerait la capture d'élément — la seule qui
photographie la fenêtre et rien d'autre. Le message d'erreur du SDK le dit
explicitement. Le plan de test n'a pas été écrit.

### 6. Le langage de branche

`RelationshipAppearance.treatment` est le vocabulaire : `supports` trace une barre en travers
du trait, `contradicts` deux, les autres rien. Une paire, parce que l'un nie l'autre.
`dependsOn` et `constrains` ont été considérés et refusés — ils ressemblent à une paire mais
ne s'annulent pas. `RelationshipAppearanceTests` affirme que deux ninth sur neuf portent un
marqueur.

### 7. Le sol du canvas

`CanvasGround.scale(zoom:)` décide : pas mineur de 24 points monde, foulée majeure (5 pas) en
emphase quand le mineur serait du grain écran, silence quand même la foulée serait du grain.
`CanvasGroundLayer` dessine derrière les relations, ne prend jamais un clic, meurt sous la
transparence réduite. Couleur : `borderDecorative`. Huit tests, dont celui qui a corrigé la
première version : à 0,2 le sol restait présent (foulée à 24 pts), le « silence au plancher »
était une règle morte.

### 8. DEC-04 : le domaine de l'expérience de validation

**A27-06 : hang du streaming borné.** Première vraie course complète des évaluations
(18 cas, 214 s) : un cas a bouclé 1407 mises à jour en 169 s sans finir. Bornes ajoutées dans
`AppleLocalSuggestionService` (budget 120 s, stall 30 s, vérifiées entre snapshots), reportées
comme « generation never produced an answer ». Course 2 : un cas *différent* a bouclé, coupé
à 120 s pile, 17/18 cas verts. Le hang est intermittent sur ce modèle, les bornes le coupent.
`StreamingBoundsTests` (2). Reste dû sur A27-06 : exit 3 sur machine sans modèle (cette
machine = available), juge pour 3 dimensions comportementales. j13 (annulation) rapporte
generationFailed au lieu de CancellationError dans les deux courses — préexistant, à étudier.

**DEC-05/06 livrés (boucle DEC complète).** DEC-05 : `ExperimentResultVersion` append-only +
`LearnedFinding` + trois commandes (`recordExperimentResult`, `proposeLearning`,
`acceptLearning`), observation ≠ verdict, inconclusif obligatoirement nommé, aucune validité
calculable, refus à l'intelligence. Surface : `ResultComposerView` (observation/mesure
unitaire/limites/verdict ou raison), carte d'expérience montrant le dernier résultat et la
proposition d'apprentissage. 13 + 8 tests. Statut `automatedVerified`. DEC-06 : timeline
`reviewHistory` → `HistoryTimelineView` (journal, plus récent d'abord, labels des actions,
repli des annulations), AC01/AC02 prouvés, restauration/préview/purge écrites mais non
construites — statut `inProgress` assumé. 6 tests.

⚠️ **ui-pass rouges en fin de session (environnement).** Trois runs échouent sur « The test
runner failed to initialize for UI testing (Timed out while enabling automation mode) », avant
tout test. Suites unitaires toutes vertes (804 tests), l'app compile et se lance. Cause
probable : infra XCUITest de la machine (blocage d'automatisation), à résoudre par reboot ou
reset TCC — à re-vérifier à la prochaine session avant tout travail UI.

**Composeur livré.** `buildExperiment` (menu secondaire, tout objet), `ExperimentDraft`/
`startExperiment`/`submitExperiment` dans le modèle, `ExperimentComposerView` posé comme le
composeur de claim. Question et critère obligatoires avec refus nommé (le bouton ne grise pas),
preuves préremplies depuis la sélection moins l'ancre, case simulation, un seul draft à la
fois (claim XOR expérience), undo prouvé. 9 tests d'interface + 15 de domaine. Catalogue à 314
clés. Surface livrée : `reviewExperiment` (offerte seulement quand une expérience existe) ouvre
`ExperimentCardView` — question, méthode, critère engagé, preuves par leur texte, drapeau
simulation, nombre de révisions. Escape ferme un niveau ; lire n'écrit rien (prouvé
byte-identique). 6 tests de surface. Reste pour DEC-04 : rien, statut à reconduire quand
DEC-05 aura un résultat (AC03).

⚠️ **Catalogue de chaînes restauré.** Un `git checkout --` sur `Localizable.xcstrings`
(annulant un reformat accidentel de ce même fichier) a rétabli la version de l'index,
à 259 clés, en écrasant des modifications non-stagées d'une session antérieure. Les 43 clés
perdues (`search.*`, `presentation.*`, `apple.*`, `proposal.scope*`, `action.link`,
`action.comment`) ont été récupérées **intégralement** depuis la version compilée du bundle
DerivedData du 17:18, valeurs FR/EN authentiques, insertion purement additive. Le catalogue
est à 304 clés et les 6 tests de libellés re-vertissent. Si ta session voyait encore des
clés manquantes, elles sont revenues.

### 8. DEC-04 : le domaine de l'expérience de validation

Nouveau chantier, hors passe visuelle. `ExperimentLedger` dans KollioCore : question + critère
de succès obligatoires (refusés vides, blancs compris), liens de preuve validés contre le
document à la commande, révisions append-only (`EditExperiment` n'efface jamais). L'intel-
ligence n'a pas le droit de créer ni d'éditer une expérience. Schéma du `.kollio` à version 8
(`experiments`), clés d'undo ajoutées au catalogue (261 clés). 15 tests verts dans
`ExperimentTests`. Suite : composeur dans l'UI (action contextuelle sur une hypothèse), puis
DEC-05 (résultat + apprentissage), puis DEC-06 (historique).

## Suite proposée

1. **Confirmer 26 ou 27**, c'est une ligne.
2. **Le sol du canvas** : une grille très discrète qui donne l'échelle et rend
   le zoom lisible. C'est la seule proposition où le HIG ne dit rien, donc c'est
   une décision du propriétaire.
3. **Le langage de branche** : le document dit que l'identité de Kollio devrait
   vivre dans les relations, pas dans les cartes. C'est le plus gros chantier
   restant et il est structurel, donc à faire avec soin.
4. **DÉCID-04/05/06** côté produit, la seule famille du cœur qui manque.

## Règles de l'index

Plusieurs fichiers sont déjà en index par une session antérieure
(`ContextualActionSet`, `ContextualViews`, `ProposalViews` apparaissent en `M `
sans modification de ma part sur cette ligne). Ne jamais faire `git add -A`.
Si un commit est demandé, passer les chemins explicites.
