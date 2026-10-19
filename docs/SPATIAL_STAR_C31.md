# Kollio C2.11 — STAR: Échap, édition et brouillons récupérables

## Situation (CAN-02 / CAN-04)
Dans Spatial Ink V3, changer de carte ou fermer l’éditeur jetait un texte non validé. La vue ne définissait pas de hiérarchie Échap. Les conflits de version étaient refusés correctement par le modèle mais les deux versions n’étaient pas visibles côte à côte.

## Task
Échap ferme l’édition avant de fermer la sélection, conserve un brouillon modifié dans la session de fenêtre, et ne touche pas au document tant qu’aucune confirmation explicite ne passe les contrôles du moteur.

## Actions
- Extraire l’inspecteur et l’éditeur en vues SwiftUI composées pour éviter les délais du compilateur sur un seul body.
- Stocker les brouillons dans SpatialDraftMemory par identité sémantique et code de langue ; les deux représentations d’un même objet retrouvent donc le même brouillon dans la même langue. Retour explicite au texte initial supprime le brouillon de cette variante.
- Pauser lors d’Échap, du bouton Fermer et du changement de sélection, puis proposer « Reprendre le brouillon ».
- Conserver la version optimiste initiale. En cas de conflit, afficher la version courante, garder mon brouillon et demander une réconciliation explicite avant la nouvelle confirmation. Une correction du code réactualise le texte de référence après réconciliation ; une modification de langue pendant l'éditeur refuse une écriture vers une autre variante.
- Ne modifier le modèle réel que par SpatialDocumentEditor.updateText ; Cmd+Entrée demande une validation, aucun déplacement ni sauvegarde implicite.
- Localiser les messages FR/EN ; tests de hiérarchie Échap, isolation des langues, récupération, conflits et correction.

## Results — preuves nécessaires
- **PASS** : 18/18 tests ciblés, puis **385/385 tests Swift** dans 43 suites après le dernier correctif ; catalogue FR/EN, conformité des vues générées et contrôle du diff.
- **PASS** : captures natives NSHostingView FR et EN à 900 × 700, exécutées et inspectées : 6 objets métier et 7 représentations. Captures hors Git dans review/c31/evidence/c31-fr.png et c31-en.png. Les captures montrent le repos du canvas, pas encore le panneau d'édition actif.
- CI GitHub native-spatial avant fusion.

## Limites honnêtes
- La récupération des brouillons est limitée à la session de cette fenêtre : pas encore une sauvegarde de brouillons sur disque entre deux lancements.
- Échap et Cmd+Entrée au clavier physique, VoiceOver et Focus restent à valider par une personne sur l’application réellement lancée.

## Suite
C2.12 : gestion de cycle de vie des brouillons (fermeture de fenêtre, sauvegarde explicite, notifications de contenu non encore validé), puis tests UX avant clôture CAN-04.