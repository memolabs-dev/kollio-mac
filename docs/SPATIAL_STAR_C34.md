# Kollio C2.14 — STAR : parcours réel fermeture/reprise macOS

## Situation
C2.13 protégeait les brouillons avec un proxy NSWindowDelegate, mais les tests invoquaient surtout ses fonctions directement. Ils ne validaient pas que le vrai `SpatialV3WindowView` était monté, que le bouton natif de fermeture passait par le proxy, ni le cas d'une fenêtre déjà fermée encore retenue par AppKit pendant un futur `Cmd+Q`.

## Task
Rejouer le parcours de fermeture sur une vraie `NSWindow` avec `NSHostingView` et document sémantique réel, et éviter les avertissements doublés sans perdre les garanties d'AppKit.

## Actions
- Test natif isolé et **opt-in** `KOLLIO_SPATIAL_C34_NATIVE=1` : fenêtre document 900×700 avec une Nouvelle idée non confirmée, utilisation réelle de `window.performClose(nil)`, refus conservant la fenêtre et le document, confirmation fermant la fenêtre, réouverture avec un état de brouillon neuf, modèle sémantique inchangé.
- Correction ciblée : `SpatialNativeCloseDelegate.windowWillClose` mémorise une vraie fermeture ; `confirmQuitIfNeeded` ignore les proxys de fenêtres déjà fermées, même lorsque la `NSWindow` reste retenue par un processus AppKit.
- Le refus propre au précédent délégué AppKit est vérifié **avant** de demander un abandon destructif, évitant la confirmation trompeuse d'une fenêtre de toute façon impossible à fermer.
- Tests de non-régression pour l'ordre des refus et l'absence de seconde confirmation, et contrôles des specs générées.

## Résultats
- Première exécution du parcours natif avant correction : **1/1 PASS**, `performClose` et réouverture validés.
- Parse Swift, index et statut OpenSpec, `git diff --check` : **PASS**.
- **PASS** : après correctif, 6/6 tests natifs ciblés (C2.13 + C2.14) et **393/393 tests KollioApp dans 45 suites**.
- **PASS** : synchronisation du générateur `scripts/sync-xcodeproj.py`, puis vrai build Xcode `Kollio` (Debug, macOS) réussi. Sans la synchronisation, Xcode ne compilait pas les sources `SpatialV3`, malgré la suite SwiftPM verte.
- **PASS** : correction des avertissements d'isolation `@MainActor` sur le proxy de délégué AppKit ; plus d'avertissement Swift de ce code au build Xcode.
- **PASS** : nouveau garde-fou CI régénérant le `.xcodeproj` puis refusant tout diff, suivi d'une vraie compilation `xcodebuild` avant les tests SwiftPM. Vérification locale de l'idempotence du générateur réussie.
- La CI de C2.13 (run 38405494112) est verte ; la nouvelle CI de C2.14 devra encore être observée après publication.

## Limites
- Une vraie `NSWindow` et une vraie commande native `performClose` testées automatiquement ne sont pas équivalentes à un clic humain, à l'annonce VoiceOver ou au trajet physique Cmd+Q.
- La persistance de brouillons entre fermetures n'est pas implémentée : la perte après une confirmation est intentionnelle et affichée.
- Pas de validation de sortie forcée, plantage macOS, fermeture non-standard par code tiers ni rétention hors fenêtre.

## Suite
Contrôler les messages de dialogue et la navigation clavier/focus avec une personne sur le Mac. Un futur lot séparé décidera si les brouillons doivent bénéficier d'une reprise explicitement consentie, indépendante du fichier canonique.

## Revue de CI — correctif Swift 6

- Situation : la PR C2.14 a révélé une erreur Swift 6 sur le runner Xcode 27 : le proxy AppKit retournait un NSWindowDelegate non Sendable hors du bloc MainActor.assumeIsolated.
- Task : conserver le comportement du délégué natif sans désactiver les vérifications de concurrence ni affaiblir la protection des brouillons.
- Actions : le pont de délégation encapsule une référence synchrone dans un type explicitement @unchecked Sendable ; MainActor.assumeIsolated continue d’exiger l’exécution sur le main actor. Aucun transfert à une tâche concurrente.
- **Résultats locaux PASS :** génération du projet Xcode idempotente ; vrai build macOS Debug Swift 6 réussi ; 6/6 tests de délégation natifs, dont une vérification de transfert du callback optionnel ; 1/1 test de fermeture et réouverture de NSWindow ; **394/394 tests KollioApp en 45 suites**. CI GitHub à revérifier après mise à jour de la PR.
