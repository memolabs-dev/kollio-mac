# Kollio C2.15 — STAR : pincement annulable et zoom stable

## Situation
Le zoom Spatial Ink utilisait `@State lastPinch` et appliquait chaque delta durant `MagnifyGesture.onChanged`. Une interruption native n'appelle pas forcément `onEnded` : le facteur accumulé pouvait alors rester périmé et le premier événement du geste suivant provoquer un saut. Un zoom incomplet était également enregistré comme modification de caméra.

## Task
Rendre l'aperçu du pincement éphémère, comme les previews de drag/pan : la caméra canonique de présentation ne doit être modifiée **qu'au terme** d'un geste valide. Un geste annulé ne doit conserver aucun facteur d'un pincement antérieur. Préserver l'ancrage central et les limites de zoom. Un pincement concurrent avec un drag/pan ne doit pas effectuer un second déplacement.

## Actions
- Remplacer `@State lastPinch` par `@GestureState pinchPreview` qui revient à 1 automatiquement lors de l'interruption ou de la disparition de la vue.
- Utiliser une seule transformation pure `SpatialPinchTransaction.camera` pour calculer l'aperçu de caméra et le résultat final, à partir d'un facteur *total* relatif au début du geste.
- Seule `onEnded` met à jour l'état `camera` et le drapeau `cameraEdited`, et uniquement si aucun drag de carte ou pan du fond n'est actif.
- Garder le calcul indépendant du domaine; refuser les facteurs non finis, nuls ou négatifs ainsi que les viewports invalides.
- Cinq tests couvrent l'annulation, le redémarrage du pincement, l'ancre, les gestes en conflit, les valeurs invalides et les limites de zoom.

## Résultats à valider
- **PASS** : cinq tests ciblés (5/5) et suite KollioApp complète **398/398 tests dans 46 suites**, sur le Mac.
- **PASS** : vrai build Xcode de la cible macOS Kollio en Debug arm64.
- **PASS** : parse Swift, index et statut OpenSpec, conformité idempotente du projet Xcode généré, `git diff --check`.
- **PASS** : deux rendus natifs `NSHostingView` 900×700 FR et EN, avec les 6 objets/7 occurrences et document immuable, inspectés visuellement. Captures hors Git : `review/c35/evidence/c35-fr.png` et `c35-en.png`. Elles montrent le canvas au repos, **pas un pincement réel**.
- CI native GitHub et interruption physique du trackpad : distincts, non revendiqués.

## Limites et suite
Un test de calcul et une compilation native ne prouvent pas le ressenti d'un trackpad réel ni le comportement VoiceOver/Tab. Le pan deux doigts reste une dette à traiter séparément : ne pas prétendre que cette correction implémente ce geste. Le nouveau chantier doit valider précisément le scroll local sans détourner celui du champ texte ou des barres du document.
