# Kollio C2.9 — STAR: langue et accessibilité clavier

## Situation
- Spatial Ink mélangeait du texte d’interface français et anglais lors de la capture native C2.8 ; la plupart des libellés n’utilisaient pas le catalogue.
- Les commandes fléchées des cartes pouvaient confondre navigation au clavier et déplacement réel.
- Le recentrage animait la caméra même avec Reduce Motion activé.
- Specs : CAN-02 (navigation et focus), CAN-03 (déplacement), DOC-08 AC01/03 (langue et préférences système).

## Task
- Localiser l’interface Spatial Ink selon la langue active (FR/EN) sans traduire ni modifier le contenu du document.
- Réserver le déplacement aux boutons explicites ou aux actions VoiceOver ; préserver le parcours clavier.
- Respecter Reduce Motion, ajouter tests et preuves natives.

## Actions
- Introduire SpatialV3Copy pour récupérer les chaînes localisées du catalogue et formater les comptes sans toucher à LocalizedText.
- Localiser les contrôles, messages, statuts, rôles, mentions d’accessibilité.
- Retirer onMoveCommand des cartes, conserver les boutons sélectionnés et actions VoiceOver nommées.
- Exposer l’état sélectionné à l’accessibilité et respecter accessibilityReduceMotion.
- Étendre la capture native NSHostingView à un modèle de document en français ou anglais.

## Results — critères de sortie
- **PASS** : 14/14 tests ciblés ; 378/378 tests Swift dans 42 suites ; contrôle du catalogue (55 clés référencées, 0 manquante, FR/EN pour toutes) ; `git diff --check`.
- **PASS** : captures natives NSHostingView dans les deux langues, inspectées visuellement ; 6 objets métier / 7 représentations, sans mutation du document. Captures hors Git dans `review/c29/evidence/c29-fr.png` et `c29-en.png`.
- **Découverte et correction** : SwiftPM choisissait la localisation `en` du bundle même avec une locale `fr` fournie à `String(localized:)` ; sélectionner explicitement le bundle de ressources compilées `fr.lproj` / `en.lproj` restaure la langue document.
- Restent humains : navigation clavier et focus réel, VoiceOver, gestes souris/trackpad, lecture à contraste élevé et Reduce Motion.
- Le code, les documents utilisateur et le checkout original de Kollio restent isolés.

## Suite de la boucle
- C2.10 : audit indépendant de la hiérarchie d’accessibilité native et du parcours clavier, puis remédiation des défauts mesurables.