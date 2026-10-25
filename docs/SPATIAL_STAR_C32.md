# Kollio C2.12 — STAR : état des brouillons et sauvegarde explicite

## Situation
- La commande Enregistrer écrit uniquement le document canonique, pas le texte inachevé d'un éditeur ni celui du champ Nouvelle idée.
- Après C2.11, les brouillons sont conservés uniquement dans la fenêtre. Le retour simple « Document enregistré » pouvait tromper sur leur persistance.
- CAN-04 exige la récupération sans mutation implicite ; DOC-04 contrôle la sauvegarde et la reprise.

## Task
- Montrer les saisies non confirmées sans les assimiler à des modifications enregistrées.
- Rendre l'état visible même lorsqu'aucune carte n'est sélectionnée ; ne jamais doubler le comptage d'une édition active et pausée du même objet/langue.
- Ajouter un abandon explicite et confirmé d'un seul brouillon, sans toucher au contenu du document.

## Actions
- Introduire SpatialPendingInput.count (fonction pure de la mémoire de brouillons, éditeur actif, nouvelle idée non soumise).
- Introduire SpatialSaveFeedback.message : le résultat de la commande Save reste vrai, mais son libellé avertit des textes non sauvegardés.
- Ajouter une alerte visible persistante au-dessus du canvas et une confirmation d'abandon de brouillon dans l'éditeur.
- Ajouter six clés de traduction FR/EN ; tests avec sauvegarde/rechargement d'un vrai document et absence du texte non validé sur disque.

## Results — critères
- **PASS** : 20/20 tests ciblés et 387/387 tests Swift dans 43 suites après les derniers changements. Les vues de specs, le catalogue JSON, la syntaxe Swift et le diff sont vérifiés.
- **PASS** : deux captures réelles NSHostingView FR et EN en fenêtre compacte, avec idée non validée et avertissement visibles, inspectées. Les tests confirment que le document n'a pas changé. Captures hors Git : review/c32/evidence/c32-pending-fr.png et c32-pending-en.png.
- Ne pas qualifier de récupération sur disque : la mémoire de brouillons reste limitée à la fenêtre ouverte. La fermeture système n'est pas encore interceptée. Le message affiché l'annonce explicitement.
- Appels de touches réelles, hiérarchie VoiceOver et focus matériel à valider par une personne.

## Suite
- C2.13 : scénario réel de l'éditeur ouvert, fermeture native de la fenêtre avec un brouillon ; choisir une politique de protection (sauvegarde locale séparée et consentie, ou confirmation bloquante), puis tester de bout en bout.