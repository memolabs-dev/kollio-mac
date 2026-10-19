# Kollio C2.13 — STAR : fermeture native et brouillons non confirmés

## Situation
C2.12 montre ce que l'enregistrement canonique ne sauve pas, mais la croix native de macOS et Cmd+Q pouvaient toujours perdre les brouillons de la fenêtre sans consentement. La mémoire reste volontairement limitée à la fenêtre.

## Task
Un texte non confirmé doit bloquer la fermeture ordinaire et la sortie de l'application tant qu'un choix humain explicite n'a pas été formulé. Annuler doit laisser la fenêtre, l'éditeur et le document inchangés. Aucun nouveau stockage de brouillons n'est implicite.

## Actions
- Nouveau `SpatialNativeCloseGuard` relié à la vue native `SpatialV3WindowView` quand un vrai modèle est présent.
- Proxy `NSWindowDelegate` qui consulte l'état dérivé `SpatialPendingInput` (compteur déjà testé en C2.12). Il transmet le veto éventuel du délégué précédent et rétablit ce délégué lors du détachement.
- Confirmation AppKit explicite, annulation par défaut, abandon seulement par choix positif. Protection de `Cmd+Q` via `AppDelegate.applicationShouldTerminate`, agrégation des saisies de toutes les fenêtres Spatial Ink encore ouvertes.
- Six nouveaux libellés FR/EN et cinq tests natifs ciblés (fermeture annulée ou autorisée, veto du délégué d'origine, agrégation sur quitter, attachement de fenêtre et localisation).

## Résultats attendus et preuves
- Parse Swift des nouveaux fichiers : **PASS**.
- **PASS** : 5/5 tests natifs ciblés C2.13 et **392/392 tests KollioApp** dans 44 suites (Mac arm64, Swift Testing).
- **PASS** : contrôle des vues OpenSpec générées, catalogue FR/EN JSON, `git diff --check`, parse Swift ; construction de la cible SwiftPM réalisée par `swift test`.
- **NON MESURÉ** : build séparé du schéma Xcode `Kollio`, comportement sur clic humain de fenêtre et VoiceOver.
- La capture d'une fenêtre ouverte ne prouve pas un vrai clic sur la croix ni Cmd+Q ; un parcours humain reste nécessaire.

## Limites
- Aucun brouillon n'est écrit sur disque : fermer après consentement les perd intentionnellement.
- Ce garde-fou protège les fermetures natives qui consultent `windowShouldClose` et la terminaison macOS usuelle. Une fin forcée de processus, une panne système ou un chemin de fermeture programmatique ne sont pas une récupération.
- Contrôles VoiceOver, focus et clavier/trackpad réels restent à valider sur le Mac.

## Suite
Tester visuellement la fermeture avec éditeur actif et la sortie par Cmd+Q, vérifier la priorité du bouton Annuler, puis décider si une persistance séparée et chiffrée des brouillons est souhaitable avant d'étendre le mécanisme.
